#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

{.experimental: "callOperator".}

import std/[pegs, strformat]
import nimpk

type
  MyVm = ref object of NpVm
    nodeCls: NpVar

  Node = ref object of RootObj
    name: string
    slice: Slice[int]
    head: Node
    tail: Node
    next: Node
    text: ref string

proc new(vm: NpVm, node: Node): NpVar =
  if node.isNil:
    result = vm.null
  else:
    result = (MyVm vm).nodeCls()
    result[] = node

proc refString[T: string|ref string](s: T): ref string =
  when T is ref:
    result = s
  else:
    new(result)
    result[] = s

proc getParser(peg: Peg, root: Node): proc (s: string): int =
  var nodeStack: seq[Node]
  result = peg.eventParser:
    pkNonTerminal:
      enter:
        nodeStack.add Node(name: p.nt.name, text: refString(root.text))

      leave:
        var node = nodeStack.pop()
        if length != -1:
          var parent: Node
          if nodeStack.len != 0:
            parent = nodeStack[^1]
          else:
            parent = root

          node.slice = start..start+length-1
          if parent.tail == nil:
            parent.tail = node
            parent.head = node

          else:
            parent.tail.next = node
            parent.tail = node

proc fill(list: NpVar, matches: openarray[string]) =
  if list of NpList:
    list.clear()
    var last = -1
    for i in countdown(matches.len - 1, 0):
      if matches[i] != "":
        last = i
        break

    for i in 0..last:
      list.add matches[i]

exportNimPk(MyVm, "pegs"):
  self.def:
    [Node] of Node:
      block:
        vm.nodeCls = self{"Node"}

      "_str" do (self: Node) -> string:
        if self.text.isNil:
          raise newException(NimPkError, "Invalid 'Node' instance.")

        result = fmt"[name: {self.name}, text: '{self.text[][self.slice]}']"

      "_getter" do (vm: NpVm, self: Node, attr: string) -> NpVar:
        if self.text.isNil:
          raise newException(NimPkError, "Invalid 'Node' instance.")

        case attr
        of "name": result = vm self.name
        of "range": result = vm self.slice
        of "head": result = vm self.head
        of "tail": result = vm self.tail
        of "next": result = vm self.next
        of "text": result = vm self.text[][self.slice]
        of "src", "source": result = vm self.text[]
        else:
          raise newException(NimPkError,
            "'Node' object has no attribute named '" & attr & "'")

    [Peg] of Peg:
      ## A PEG (Parsing expression grammar) is a simple deterministic grammar,
      ## that can be directly used for parsing. The current implementation has
      ## been designed as a more powerful replacement for regular expressions.
      ##
      ## See https://nim-lang.org/docs/pegs.html for detail grammar.

      "_init" do (self: var Peg, pattern: string):
        ## Peg(pattern: String) -> Peg
        ##
        ## Creates a instance of PEG parser.
        self = peg(pattern)

      "_str" do (self: Peg) -> string:
        return fmt"Peg(r""{$self}"")"

      parse do (vm: NpVm, self: Peg, s: string) -> Node:
        ## Peg.parse(s: string): Peg.Node
        ##
        ## returns a node that contains informations about the ast tree of
        ## the string that had been parsed.
        var
          root = Node(name: "@root", text: refString(s))
          parser = getParser(self, root)
          n = parser(s)

        if n > 0:
          root.slice = 0 ..< n
          result = root

      match do (self: Peg, s: string, matches = NpNil, start = 0) -> bool:
        ## Peg.match(s: string[, matches: List, start = 0]): bool
        ## Peg.match(s: string[, start = 0]): bool
        ##
        ## returns true if s[start..] matches the pattern and the captured substrings
        ## in the array matches. If it does not match, nothing is written into matches
        ## and false is returned.
        let start = if matches of NpNumber: int matches else: start
        var captures: array[MaxSubpatterns, string]
        result = match(s, self, captures, start)
        matches.fill(captures)

      matchLen do (self: Peg, s: string, matches = NpNil, start = 0) -> int:
        ## Peg.matchLen(s: string[, matches: List, start = 0]): Number
        ## Peg.matchLen(s: string[, start = 0]): Number
        ##
        ## the same as match, but it returns the length of the match,
        ## if there is no match, -1 is returned. Note that a match length
        ## of zero can happen. It's possible that a suffix of s remains
        ## that does not belong to the match.
        let start = if matches of NpNumber: int matches else: start
        var captures: array[MaxSubpatterns, string]
        result = matchLen(s, self, captures, start)
        matches.fill(captures)

      find do (self: Peg, s: string, matches = NpNil, start = 0) -> int:
        ## Peg.find(s: string[, matches: List, start = 0]): Number
        ## Peg.find(s: string[, start = 0]): Number
        ##
        ## returns the starting position of pattern in s and the captured
        ## substrings in the matches. If it does not match, nothing is written
        ## into matches and -1 is returned.
        let start = if matches of NpNumber: int matches else: start
        var captures: array[MaxSubpatterns, string]
        result = find(s, self, captures, start)
        matches.fill(captures)

      contains do (self: Peg, s: string, matches = NpNil, start = 0) -> bool:
        ## Peg.contains(s: string[, matches: List, start = 0]): int
        ## Peg.contains(s: string[, start = 0]): int
        ##
        ## same as Peg.find(s[, matches, start]) >= 0
        let start = if matches of NpNumber: int matches else: start
        var captures: array[MaxSubpatterns, string]
        result = contains(s, self, captures, start)
        matches.fill(captures)

      findBounds do (self: Peg, s: string, matches = NpNil, start = 0) -> HSlice[int,int]:
        ## Peg.findBounds(s: string[, matches: List, start = 0]): Range
        ## Peg.findBounds(s: string[, start = 0]): Range
        ##
        ## returns the starting position and end position of pattern in s
        ## and the captured substrings in the list matches.
        ## If it does not match, nothing is written into matches
        ## and range -1..0 is returned.
        let start = if matches of NpNumber: int matches else: start
        var captures: array[MaxSubpatterns, string]
        let ret = findBounds(s, self, captures, start)
        result = ret.first..ret.last
        matches.fill(captures)

      findAll do (self: Peg, s: string, start = 0) -> seq[string]:
        ## Peg.findAll(s: string[, start = 0]): List
        ##
        ## returns all matching substrings of s that match pattern.
        ## If it does not match, [] is returned.
        result = findAll(s, self, start)

      startsWith do (self: Peg, s: string, start = 0) -> bool:
        ## Peg.startsWith(s: string[, start = 0]): Bool
        ##
        ## returns true if s starts with the pattern prefix.
        result = startsWith(s, self, start)

      endsWith do (self: Peg, s: string, start = 0) -> bool:
        ## Peg.endsWith(s: string[, start = 0]): Bool
        ##
        ## returns true if s ends with the pattern suffix
        result = endsWith(s, self, start)

      replace do (self: Peg, s: string, by: NpVar) -> string:
        ## Peg.replace(s: string, callback: Closure): String
        ## Peg.replace(s: string, by: String): String
        ##
        ## Replaces sub in s by the resulting strings from the callback.
        ## The callback proc receives the index of the current match (starting with 0),
        ## and an list with the captures of each match.
        ## If second argument is a string, captures cannot be accessed.
        if by of NpClosure:
          if by.arity != 2:
            raise newException(NimPkError, "Arity of callback closure should be 2.")

          proc callback(m: int, n: int, c: openArray[string]): string =
            result = $by(m, c[0..<n])

          result = replace(s, self, callback)

        else:
          result = replace(s, self, $by)

      replacef do (self: Peg, s: string, by: string) -> string:
        ## Peg.replacef(s: string, by: string): String
        ##
        ## Replaces sub in s by the string `by`. Captures can be accessed in `by`
        ## with the notation $i and $#
        result = replacef(s, self, by)

      split do (self: Peg, s: string) -> seq[string]:
        ## Peg.split(s: string): List
        ##
        ## Splits the string s into substrings.
        result = split(s, self)
