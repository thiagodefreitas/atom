{View, $$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'
Range = require 'range'

module.exports =
class Autocomplete extends View
  @content: ->
    @div id: 'autocomplete', =>
      @ol outlet: 'matchesList'

  editor: null
  currentBuffer: null
  wordList: null
  wordRegex: /\w+/g
  matches: null
  currentMatchIndex: null
  isAutocompleting: false

  initialize: (@editor) ->
    requireStylesheet 'autocomplete.css'
    @on 'autocomplete:toggle', => @toggle()
    @on 'move-up', => @previousMatch()
    @on 'move-down', => @nextMatch()
    @editor.on 'buffer-path-change', => @setCurrentBuffer(@editor.buffer)

    @setCurrentBuffer(@editor.buffer)

  setCurrentBuffer: (buffer) ->
    @currentBuffer.off '.autocomplete' if @currentBuffer
    @currentBuffer = buffer
    @buildWordList()

    @currentBuffer.on 'change.autocomplete', =>
      @buildWordList() unless @isAutocompleting

  toggle: ->
    if @parent()[0] then @remove() else @show()

  show: ->
    @buildMatchList()
    @selectMatch(0) if @matches.length > 0

    cursorScreenPosition = @editor.getCursorScreenPosition()
    {left, top} = @editor.pixelOffsetForScreenPosition(cursorScreenPosition)
    @css {left: left, top: top + @editor.lineHeight}
    $(document.body).append(this)

  previousMatch: ->
    previousIndex = @currentMatchIndex - 1
    previousIndex = @matches.length - 1 if previousIndex < 0
    @selectMatch(previousIndex)

  nextMatch: ->
    nextIndex = (@currentMatchIndex + 1) % @matches.length
    @selectMatch(nextIndex)

  buildMatchList: ->
    selection = @editor.getSelection()
    {prefix, suffix} = @prefixAndSuffixOfSelection(selection)
    currentWord = prefix + @editor.getSelectedText() + suffix

    @matches = (match for match in @wordMatches(prefix, suffix) when match[0] != currentWord)

    @matchesList.empty()
    if @matches.length > 0
      @matchesList.append($$ -> @li match[0]) for match in @matches
    else
      @matchesList.append($$ -> @li "No matches found")

  buildWordList: () ->
    @wordList = _.unique(@currentBuffer.getText().match(@wordRegex))

  wordMatches: (prefix, suffix) ->
    regex = new RegExp("^#{prefix}(.+)#{suffix}$", "i")
    regex.exec(word) for word in @wordList when regex.test(word)

  selectMatch: (index) ->
    @currentMatchIndex = index
    @matchesList.find("li").removeClass "selected"
    @matchesList.find("li:eq(#{index})").addClass "selected"
    @completeUsingMatch(index)

  completeUsingMatch: (matchIndex) ->
    match = @matches[matchIndex]
    selection = @editor.getSelection()
    startPosition = selection.getBufferRange().start
    @isAutocompleting = true
    @editor.insertText(match[1])
    @editor.setSelectionBufferRange([startPosition, [startPosition.row, startPosition.column + match[1].length]])
    @isAutocompleting = false

  prefixAndSuffixOfSelection: (selection) ->
    selectionRange = selection.getBufferRange()
    lineRange = [[selectionRange.start.row, 0], [selectionRange.end.row, @editor.lineLengthForBufferRow(selectionRange.end.row)]]
    [prefix, suffix] = ["", ""]

    @currentBuffer.scanInRange @wordRegex, lineRange, (match, range, {stop}) ->
      stop() if range.start.isGreaterThan(selectionRange.end)

      if range.intersectsWith(selectionRange)
        prefixOffset = selectionRange.start.column - range.start.column
        suffixOffset = selectionRange.end.column - range.end.column

        prefix = match[0][0...prefixOffset] if range.start.isLessThan(selectionRange.start)
        suffix = match[0][suffixOffset..] if range.end.isGreaterThan(selectionRange.end)

    {prefix, suffix}
