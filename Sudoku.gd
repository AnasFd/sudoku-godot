extends Control

const ROW = 9
const COL = 9
const SIZE = 40
const SUBGRID_SIZE = 3
const GRID_SIZE = ROW * COL
const SUBGRID_COUNT = ROW / SUBGRID_SIZE
const MAXERRORS = 999

var array = []
var difficulty = "Easy" # Par default
var rng = RandomNumberGenerator.new()
var PanelScene = preload("res://Panel.tscn") # A Panel's properties
var startTime: float
var elapsedTime: float
var pauseStartTime: float
var pauseEndTime: float
var pauseTime: float = 0
var isPaused = false
var validCaseSelection = false
var validCaseRow
var validCaseCol
var errors = 0
var gameOver = false
var caseSelected = false
var currentlyFocusedButton: Button
var currentlyFocusedDifficulty: Button
var selectedCase = null

func _ready():
	setDefaultDifficultyButton()
	initGrids()
	generateNewGrid()
	connectSignals()

func _process(_delta: float):
	if errors >= MAXERRORS:
		gameOver = true
		showMaxErrorsMessage()
		# add errors message
	else:
		if not isPaused:
			updateElapsedTime()
			if isGridSolved():
				showSolvedMessage()
				isPaused = true
				gameOver = true

func connectSignals():
	# Numbers from 1 to 9 (number selector on the right)
	for button in $ColorRect/Main/Right/GridContainer.get_children():
		button.connect("pressed", self, "_on_number_press", [button])
		
	# Difficulty selector
	for button in $ColorRect/Main/Left/Difficulty.get_children():
		if button is Button: # Bah oui quoi (no seriously, it's to avoid The Label I have with the buttons)
			button.connect("pressed", self, "_on_difficulty_pressed", [button])
		
func generateNewGrid():
	init_array()
	resetVariables()
	fillDiagonalSubGrids()
# warning-ignore:return_value_discarded
	solveGrid(array)
	removeCells(difficulty)
	show()
	resetcurrentlyFocusedButton()

func setDefaultDifficultyButton():
	var easyButton = $ColorRect/Main/Left/Difficulty/easy

	if easyButton != null:
		easyButton.disabled = true

func resetcurrentlyFocusedButton():
	currentlyFocusedButton = $ColorRect/Main/Left/Panel.get_child(0).get_node("Button")
	currentlyFocusedButton.grab_focus()
	simulate_button_press()
	
func showSolvedMessage():
	var message = "Congratulations!\nSudoku solved in " + format_time(elapsedTime)
	$PopupDialog/VBoxContainer/MessageLabel.text = message
	$PopupDialog.visible = true
	
func showMaxErrorsMessage():
	var message = "Better luck next time"
	$PopupDialog/VBoxContainer/MessageLabel.text = message
	$PopupDialog.visible = true
	
func resetPopUps():
	$PopupDialog/VBoxContainer/MessageLabel.text = ""
	$PopupDialog.visible = false

func updateElapsedTime():
	var currentTime = OS.get_system_time_secs()
	elapsedTime = currentTime - startTime - pauseTime
	$ColorRect/Main/Right/ToolsInfo/TimeBox/Time.set_text(format_time(elapsedTime))

func updatePauseTime():
	pauseTime += pauseEndTime - pauseStartTime 

func updateMistakesBox():
	if errors < MAXERRORS:
		errors += 1
		$ColorRect/Main/Right/ToolsInfo/Mistakes/num.text = str(errors)

func resetVariables():
	startTime = OS.get_system_time_secs()
	rng.randomize()
	randomize()
	pauseTime = 0
	pauseStartTime = 0
	pauseEndTime = 0
	isPaused = false
	disableButtons(false)
	$ColorRect/Main/Right/ToolsInfo/TimeBox/VBoxContainer/PausePlay.visible = true
	$ColorRect/Main/Right/ToolsInfo/TimeBox/VBoxContainer/Play.visible = false
	
	# errors
	errors = 0
	$ColorRect/Main/Right/ToolsInfo/Mistakes/num.text = str(errors)
	
	caseSelected = false
	gameOver = false

func format_time(seconds: float) -> String:
	var minutes = int(seconds / 60)
	var remaining_seconds = int(seconds) % 60
	return str(minutes) + ":" + str(remaining_seconds).pad_zeros(2)

func isGridSolved() -> bool:
	return array.size() == GRID_SIZE and not array.has(null)

func show():
	var gameGrid = $ColorRect/Main/Left/Panel
	for i in range(ROW):
		for j in range(COL):
			var panel = gameGrid.get_child(i * ROW + j)
			var button = panel.get_node("Button")
			button.text = str(array[i * ROW + j]) if array[i * ROW + j] != null else ""

func initGrids():
	var gameGrid = $ColorRect/Main/Left/Panel
# warning-ignore:integer_division
	var initialOffset = 102 * 2 # center
	var offsetX = 0
	var offsetY = initialOffset - 180
	
	# Grid
	for i in range(ROW):
		offsetX = initialOffset - 100
		offsetY += 2 + 2 * int(i % 3 == 0)
		for j in range(COL):
			offsetX += 2 + 2 * int(j % 3 == 0)
			var panel = PanelScene.instance()
			panel.rect_position = Vector2(SIZE * j, SIZE * i) + Vector2(offsetX, offsetY)
			var button = panel.get_node("Button")
			button.connect("pressed", self, "_on_button_pressed", [i, j])
			gameGrid.add_child(panel)

func init_array():
	array = []
	for _i in range (GRID_SIZE):
		array.append(null)

func fillDiagonalSubGrids():
	for n in range(SUBGRID_COUNT):
		var tmp = [1, 2, 3, 4, 5, 6, 7, 8, 9]
		tmp.shuffle()
		for i in range(n * SUBGRID_SIZE, (n + 1) * SUBGRID_SIZE):
			for j in range(n * SUBGRID_SIZE, (n + 1) * SUBGRID_SIZE):
				array[i * ROW + j] = tmp.pop_back()

func hasSolution(grid: Array) -> bool:
	var gridCopy = grid.duplicate()
	return solveGrid(gridCopy)

func solveGrid(grid: Array) -> bool:
	var emptyCell = findEmptyCell(grid)
	if not emptyCell:
		return true

	var row = emptyCell[0]
	var col = emptyCell[1]

	for candidate in getCondidates(row, col, grid):
		grid[row * 9 + col] = candidate

		if solveGrid(grid):
			return true

		grid[row * 9 + col] = null

	return false

func findEmptyCell(grid: Array):
	for i in range(ROW):
		for j in range(COL):
			if not grid[i * ROW + j]:
				return [i, j]

	return null

func getCondidates(i, j, grid) -> Array:
	var takenNumbers = getRowNumbers(i, grid) + getColNumbers(j, grid) + getSubGridNumbers(i, j, grid)
	var candidates = []

	for number in range(1, 10):
		if not (number in takenNumbers) and isValidMove(grid, i, j, number):
			candidates.append(number)

	return candidates

func getRowNumbers(i, grid):
	var rowResult = []
	for j in range(ROW):
		var number = grid[i * ROW + j]
		if number:
			rowResult.append(number)

	return rowResult

func getColNumbers(j, grid):
	var colResult = []
	for i in range(ROW):
		var number = grid[i * ROW + j]
		if number:
			colResult.append(number)

	return colResult

func getSubGridNumbers(i, j, grid):
	var offset_i = int(i / 3) * 3
	var offset_j = int(j / 3) * 3
	var subgridResult = []

	for subgrid_i in range(offset_i, offset_i + 3):
		for subgrid_j in range(offset_j, offset_j + 3):
			var number = grid[subgrid_i * ROW + subgrid_j]
			if number:
				subgridResult.append(number)

	return subgridResult

func removeCells(_difficulty):
	var cellsToRemove = getCellsToRemove(_difficulty)
	var remainingCells = GRID_SIZE  # Total number of cells in the grid

	while cellsToRemove > 0 and remainingCells > 0:
		# Get a random cell within the grid
		var _row = randi() % 9
		var _col = randi() % 9

		# Ensure the cell is not already empty
		if array[_row * 9 + _col] != null:
			# Remove the value from the cell
			array[_row * 9 + _col] = null
			remainingCells -= 1

			# Ensure symmetry by removing the corresponding cell
			var symmetricalRow = 8 - _row
			var symmetricalCol = 8 - _col
			array[symmetricalRow * 9 + symmetricalCol] = null
			remainingCells -= 1

			# Decrease the count of cells to remove
			cellsToRemove -= 2

			# removal from different subgrids
			if _row % 3 == 0:
				# If the cell is in the first row of a subgrid, remove its counterpart from a different subgrid
				var randomSubgrid = rng.randi_range(1, 2) * 3
				array[symmetricalRow * 9 + randomSubgrid] = null
				remainingCells -= 1

			# Ensure removal from different rows and columns
			var randomRow = rng.randi_range(0, 2) * 3 + (_row % 3)
			var randomCol = rng.randi_range(0, 2) * 3 + (_col % 3)
			array[randomRow * 9 + randomCol] = null
			remainingCells -= 1

func getCellsToRemove(_difficulty):
	match difficulty:
		"Easy":
			return rng.randi_range(1, 1) # 30 35
		"Medium":
			return rng.randi_range(20, 25) # 35 40 
		"Hard":
			return rng.randi_range(30, 40) # 45 50
			
	return 0  # 0 cells to remove if difficulty is unknown

func disableButtons(disable: bool):
	var gameGrid = $ColorRect/Main/Left/Panel

	for button in gameGrid.get_children():
		var buttonNode = button.get_node("Button")
		#if buttonNode != null:
		buttonNode.disabled = disable

func _on_difficulty_pressed(button):
	# Re-enable all difficulty buttons
	for difficultyButton in $ColorRect/Main/Left/Difficulty.get_children():
		if difficultyButton is Button:
			difficultyButton.disabled = false

	# Disable the selected difficulty button
	button.disabled = true

	if button.text != difficulty:
		currentlyFocusedDifficulty = button
		difficulty = button.text
	print(difficulty)

func _on_PausePlay_pressed():
	var pauseButton = $ColorRect/Main/Right/ToolsInfo/TimeBox/VBoxContainer/PausePlay
	var playButton = $ColorRect/Main/Right/ToolsInfo/TimeBox/VBoxContainer/Play
	
	if not gameOver:
		if isPaused:
			print("lewla, isPaused :",isPaused)
			pauseEndTime = OS.get_system_time_secs()
			updatePauseTime()
			isPaused = false
			pauseButton.visible = true
			playButton.visible = false
			disableButtons(false)
		else:
			pauseStartTime = OS.get_system_time_secs()
			print("tanya, isPaused :",isPaused)
			isPaused = true
			pauseButton.visible = false
			playButton.visible = true
			disableButtons(true)

func _on_New_Game_pressed():
	resetPopUps()
	revertOgColor()
	generateNewGrid()

func _on_button_pressed(_row, _col):
	if not isPaused and not gameOver:
		print("Button Pressed - Row: ", _row, " Column: ", _col)
		# Purely decorative
		revertOgColor()
		highlightSurroundings(_row,_col)
		
		# Game Logic
		if array[_row * ROW + _col] == null:
			caseSelected = true
			selectedCase = Vector2(_row,_col)
			validCaseSelection = true
			validCaseRow = _row
			validCaseCol = _col
		else:
			validCaseSelection = false
			validCaseCol = null
			validCaseRow = null
			focusSameNumbers(_row, _col)
			caseSelected = false
			selectedCase = null
		
		# Set focus to the current button
		var panel = $ColorRect/Main/Left/Panel.get_child(_row * ROW + _col)
		currentlyFocusedButton = panel.get_node("Button")
		currentlyFocusedButton.grab_focus()

func focusSameNumbers(_row, _col):
	var numberToFocus = array[_row * ROW + _col]
	var focusColor = Color(0.760784, 0.866667, 0.972549)

	for button in $ColorRect/Main/Left/Panel.get_children():
		var buttonNode = button.get_node("Button")
		if buttonNode != null and buttonNode.text == str(numberToFocus):
			ColorButton(buttonNode, focusColor)

# Hilights the row, col, and subgrid of selected Button
func highlightSurroundings(selected_row, selected_col):
	var highlightColor = Color(0.894118, 0.921569, 0.94902)
	var gameGrid = $ColorRect/Main/Left/Panel

	# Highlight the selected row
	for _col in range(COL):
		var panel = gameGrid.get_child(selected_row * ROW + _col)
		var buttonToHighlight = panel.get_node("Button")
		ColorButton(buttonToHighlight, highlightColor)

	# Highlight the selected column
	for _row in range(ROW):
		var panel = gameGrid.get_child(_row * ROW + selected_col)
		var buttonToHighlight = panel.get_node("Button")
		ColorButton(buttonToHighlight, highlightColor)

	# Highlight the selected subgrid
	var subgrid_row = int(selected_row / 3) * 3
	var subgrid_col = int(selected_col / 3) * 3
	for i in range(3):
		for j in range(3):
			var panel = gameGrid.get_child((subgrid_row + i) * ROW + (subgrid_col + j))
			var buttonToHighlight = panel.get_node("Button")
			ColorButton(buttonToHighlight, highlightColor)

# Helper function to highlight a button
func ColorButton(button, color):
	button.modulate = color

func revertOgColor():
	var gameGrid = $ColorRect/Main/Left/Panel
	
	for _row in ROW:
		for _col in COL:
			var panel = gameGrid.get_child(_row * ROW + _col)
			var button = panel.get_node("Button")
			ColorButton(button, Color(1, 1, 1, 1)) # White since it has no effect on the og color

func isValidMove(grid: Array, row: int, col: int, number: int) -> bool:
	# Check if the number already exists in the same row or column
	for i in range(ROW):
		if grid[row * ROW + i] == number or grid[i * ROW + col] == number:
			return false

# warning-ignore:integer_division
	var subgridRow = int(row / 3) * 3
# warning-ignore:integer_division
	var subgridCol = int(col / 3) * 3
	for i in range(subgridRow, subgridRow + 3):
		for j in range(subgridCol, subgridCol + 3):
			if grid[i * ROW + j] == number:
				return false

	# If no violations found, the move is valid
	return true

func _on_number_press(input):
	var selectedNumber
	if validCaseSelection && validCaseCol != null && validCaseRow != null:
		if is_instance_valid(input) and input is Button:
			# Si l'entrée est un bouton, obtenir le numéro à partir du texte du bouton
			selectedNumber = int(input.text)
		elif typeof(input) == TYPE_INT:
			# Si l'entrée est un numéro, l'utiliser directement
			selectedNumber = input
		else:
			print("Entrée invalide")
			return
		var candidates = getCondidates(validCaseRow, validCaseCol, array)
		
		if selectedNumber in candidates:
			# Make a copy of the current grid
			var gridCopy = array.duplicate()

			# Update the copy with the selected number
			gridCopy[validCaseRow * ROW + validCaseCol] = selectedNumber

			# Check if the move is valid and the grid has a solution
			if hasSolution(gridCopy):
				array[validCaseRow * ROW + validCaseCol] = selectedNumber
				show()
			else:
				# If it doesn't have a solution or the move is not valid, print an error message and revert the change
				print("Invalid move: This move leads to an unsolvable grid")
				array[validCaseRow * ROW + validCaseCol] = null
				updateMistakesBox()
		else:
			print("Invalid move: Selected number is not a valid candidate.")
			updateMistakesBox()

func _input(event):
	if event is InputEventKey and event.pressed and validCaseSelection:
		print("Scancode:", event.scancode)
		if event.scancode >= KEY_1 and event.scancode <= KEY_9:
			var number = event.scancode - KEY_1 + 1
			_on_number_press(number)

func simulate_button_press():
	if currentlyFocusedButton != null:
		# Get the row and column of the currently focused button
		var panel = currentlyFocusedButton.get_parent()
		var index = panel.get_index()
		var _row = int(index / ROW)
		var _col = index % ROW

		# Call the _on_button_press function with the row and column
		_on_button_pressed(_row, _col)
