extends Node2D

const FONT = preload("res://assets/fonts/Roboto-Bold.ttf")

const GOLD        = Color(0.941, 0.753, 0.251, 1)
const GOLD_DIM    = Color(0.549, 0.392, 0.055, 1)
const WHITE       = Color(0.92, 0.92, 0.92, 1)
const DIM         = Color(0.47, 0.60, 0.71, 1)
const TERMINAL    = Color(0.20, 0.90, 0.30, 1)
const BG_DARK     = Color(0.04, 0.08, 0.04, 1)
const BG_PANEL    = Color(0.05, 0.11, 0.17, 1)
const STEEL       = Color(0.07, 0.14, 0.22, 1)
const COL_EASY    = Color(0.18, 0.80, 0.44, 1)
const COL_INTER   = Color(0.96, 0.77, 0.09, 1)
const COL_ADV     = Color(0.91, 0.30, 0.24, 1)
const AMBER_TEXT  = Color(0.96, 0.77, 0.09, 1)

const ALGO_DATA: Dictionary = {
	"Bubble Sort": {
		"tier": "EASY", "tier_color": COL_EASY,
		"introduction": "Bubble Sort is one of the simplest sorting algorithms you will ever encounter. It works by repeatedly walking through a list and comparing two neighboring items at a time. If they are in the wrong order, swap them. After each full pass, the largest unsorted value has bubbled to its correct spot at the end. It keeps going until no swaps are needed.",
		"what_it_is": "Comparison-based, stable, in-place exchange sort. Equal elements maintain their original relative order. Requires no extra memory beyond a temporary swap variable.",
		"core_concept": "With every pass through the list, the largest remaining unsorted element gets pushed to its final position, just like a bubble rising to the surface of water. After n-1 passes, every element is in the right place.",
		"how_it_works": [
			"Start at the beginning of the list.",
			"Compare the first two adjacent elements.",
			"If the left one is greater than the right one, swap them.",
			"Move one position to the right and repeat steps 2 and 3.",
			"After reaching the end, the largest element is in its final position.",
			"Repeat from step 1, ignoring the last already-sorted element.",
			"Stop when a full pass completes with zero swaps."
		],
		"complexity": {"best": "O(n)", "average": "O(n²)", "worst": "O(n²)", "space": "O(1)"},
		"pseudocode": "FOR i = 0 TO n-2:\n  swapped = false\n  FOR j = 0 TO n-2-i:\n    IF array[j] > array[j+1]:\n      swap(array[j], array[j+1])\n      swapped = true\n  IF NOT swapped:\n    BREAK  // already sorted",
		"when_to_use": [
			"Teaching or learning sorting for the first time.",
			"The list is very small, under around 20 elements.",
			"The list is nearly sorted with only a few swaps expected.",
			"Simplicity of implementation matters more than speed."
		],
		"real_world": "Bubble Sort is rarely used in production. It occasionally appears in embedded systems with tiny fixed datasets where implementation simplicity beats efficiency, and it remains a staple of CS education worldwide.",
		"quick_comparison": "Bubble Sort vs Selection Sort: both are O(n²), but Bubble Sort makes more swaps while Selection Sort makes at most n-1 swaps, making Selection Sort better when writes are expensive."
	},
	"Selection Sort": {
		"tier": "EASY", "tier_color": COL_EASY,
		"introduction": "Selection Sort divides the list into a sorted section on the left and an unsorted section on the right. On each pass it scans the entire unsorted section, finds the smallest element, and drops it into the next sorted position. It is straightforward to understand but makes no attempt to take advantage of an already-sorted list.",
		"what_it_is": "Comparison-based, unstable, in-place sorting algorithm. Unstable because swapping a minimum element into position can disrupt the relative order of equal elements. Performs at most n-1 swaps regardless of input.",
		"core_concept": "Each pass selects the minimum from the unsorted remainder and places it at the boundary of the sorted region. The sorted boundary grows by one element per pass until the whole list is sorted.",
		"how_it_works": [
			"Set the current position i = 0, start of unsorted region.",
			"Assume element at i is the minimum and record its index.",
			"Scan every element from i+1 to end of list.",
			"If a smaller element is found, update the minimum index.",
			"After the scan, swap the minimum with the element at position i.",
			"Increment i so the sorted region grows by one.",
			"Repeat from step 2 until i = n-1."
		],
		"complexity": {"best": "O(n²)", "average": "O(n²)", "worst": "O(n²)", "space": "O(1)"},
		"pseudocode": "FOR i = 0 TO n-2:\n  minIdx = i\n  FOR j = i+1 TO n-1:\n    IF array[j] < array[minIdx]:\n      minIdx = j\n  IF minIdx != i:\n    swap(array[i], array[minIdx])",
		"when_to_use": [
			"Write operations are expensive, such as on flash memory, since it does at most n-1 swaps.",
			"You need a simple algorithm with predictable consistent performance.",
			"The dataset is small and stability is not required."
		],
		"real_world": "Selection Sort is used in scenarios where memory writes are significantly more expensive than reads, such as sorting data on EEPROM or certain embedded hardware. Its simplicity also makes it common in introductory CS curricula.",
		"quick_comparison": "Selection Sort vs Bubble Sort: same O(n²) complexity, but Selection Sort always performs exactly n-1 swaps while Bubble Sort may perform O(n²) swaps. Selection Sort wins when minimizing write operations."
	},
	"Insertion Sort": {
		"tier": "EASY", "tier_color": COL_EASY,
		"introduction": "Insertion Sort builds the sorted list one element at a time, exactly like sorting a hand of playing cards. You pick up the next card, then slide it left through your already-sorted cards until it lands in the right spot. It is efficient for small or nearly-sorted lists and is actually used inside more advanced algorithms like Tim Sort.",
		"what_it_is": "Comparison-based, stable, in-place, adaptive sorting algorithm. Performance improves significantly when the input is partially sorted. Maintains a sorted sub-array on the left, growing it by inserting one element at a time from the unsorted right portion.",
		"core_concept": "At every step, one element is taken from the unsorted region and inserted into its correct position within the already-sorted region by shifting larger elements one position to the right to make room.",
		"how_it_works": [
			"Start with the second element since the first is trivially sorted.",
			"Store the current element as the key.",
			"Compare the key against each element to its left.",
			"While the left element is greater than the key, shift it one position right.",
			"Insert the key in the gap created.",
			"Move to the next element and repeat from step 2."
		],
		"complexity": {"best": "O(n)", "average": "O(n²)", "worst": "O(n²)", "space": "O(1)"},
		"pseudocode": "FOR i = 1 TO n-1:\n  key = array[i]\n  j = i - 1\n  WHILE j >= 0 AND array[j] > key:\n    array[j+1] = array[j]\n    j = j - 1\n  array[j+1] = key",
		"when_to_use": [
			"The list is small, under around 20 elements.",
			"The list is nearly sorted with very few elements out of place.",
			"You need a stable sort with O(1) extra space.",
			"Online sorting where elements arrive one at a time and must be sorted as they come in."
		],
		"real_world": "Insertion Sort is used as the base case in Tim Sort for small sub-arrays, typically of size 64 or less. Python's and Java's default sort both rely on it internally. Many card game apps use it as their primary algorithm.",
		"quick_comparison": "Insertion Sort vs Selection Sort: both are O(n²), but Insertion Sort is adaptive, faster on nearly-sorted data, and stable, while Selection Sort always runs in exactly O(n²) and is unstable."
	},
	"Merge Sort": {
		"tier": "INTERMEDIATE", "tier_color": COL_INTER,
		"introduction": "Merge Sort takes a divide and conquer approach. It splits the list in half repeatedly until every piece is a single element which is trivially sorted, then merges those pieces back together in the correct order. It is the go-to algorithm when you need guaranteed O(n log n) performance and stability even in the worst case.",
		"what_it_is": "Comparison-based, stable, not-in-place divide-and-conquer sorting algorithm. Requires O(n) auxiliary space for merging. Guarantees O(n log n) time in all cases. Foundation of external sorting algorithms used when data does not fit in memory.",
		"core_concept": "Merging two already-sorted lists into one sorted list is easy and fast at O(n). Merge Sort exploits this by recursively breaking the problem into smaller sorted sub-lists, then merging them up the recursion tree.",
		"how_it_works": [
			"If the list has 1 or 0 elements it is already sorted, return.",
			"Split the list into two equal halves.",
			"Recursively sort the left half.",
			"Recursively sort the right half.",
			"Merge using two pointers, one for each half.",
			"Compare the front elements of both halves and take the smaller one into the output.",
			"Advance the pointer of the half you took from.",
			"Repeat until one half is empty, then append the remaining half to the output."
		],
		"complexity": {"best": "O(n log n)", "average": "O(n log n)", "worst": "O(n log n)", "space": "O(n)"},
		"pseudocode": "FUNCTION mergeSort(array):\n  IF length(array) <= 1: RETURN array\n  mid   = length(array) / 2\n  left  = mergeSort(array[0..mid-1])\n  right = mergeSort(array[mid..end])\n  RETURN merge(left, right)\n\nFUNCTION merge(left, right):\n  result = []\n  WHILE left AND right not empty:\n    IF left[0] <= right[0]:\n      append left[0]; remove left[0]\n    ELSE:\n      append right[0]; remove right[0]\n  append remaining elements\n  RETURN result",
		"when_to_use": [
			"You need guaranteed O(n log n) with no worst-case degradation.",
			"You need a stable sort on large datasets.",
			"Sorting linked lists where no random access is needed.",
			"External sorting where data is larger than available memory."
		],
		"real_world": "Merge Sort is the basis for external sort in database systems and is used in version control tools like Git diffs. Java's Arrays.sort() for objects uses a Merge Sort variant to preserve stability.",
		"quick_comparison": "Merge Sort vs Quick Sort: both average O(n log n), but Merge Sort is stable and has guaranteed worst-case O(n log n), while Quick Sort is in-place but degrades to O(n²) on bad pivot choices."
	},
	"Quick Sort": {
		"tier": "INTERMEDIATE", "tier_color": COL_INTER,
		"introduction": "Quick Sort is often the fastest sorting algorithm in practice. It picks a pivot element, rearranges the array so every element smaller than the pivot is to its left and every larger element is to its right, then recursively sorts both sides. The key to Quick Sort is picking a good pivot since a bad one leads to poor performance.",
		"what_it_is": "Comparison-based, unstable, in-place divide-and-conquer algorithm. In-place because partitioning is done with swaps within the original array using O(log n) stack space for recursion. Unstable because elements are swapped across distant positions during partitioning.",
		"core_concept": "Partitioning: pick a pivot, put every smaller element to its left and every larger element to its right in one linear scan. After partitioning, the pivot is in its final sorted position. Recursively apply to both sides.",
		"how_it_works": [
			"Choose a pivot, common choices are last element, first, or median-of-three.",
			"Partition: scan the array and move elements smaller than pivot to the left, larger to the right.",
			"Place the pivot in its correct final position.",
			"Recursively apply Quick Sort to the left sub-array.",
			"Recursively apply Quick Sort to the right sub-array.",
			"Base case: a sub-array of length 0 or 1 is already sorted."
		],
		"complexity": {"best": "O(n log n)", "average": "O(n log n)", "worst": "O(n²)", "space": "O(log n)"},
		"pseudocode": "FUNCTION quickSort(array, low, high):\n  IF low < high:\n    pivotIdx = partition(array, low, high)\n    quickSort(array, low, pivotIdx - 1)\n    quickSort(array, pivotIdx + 1, high)\n\nFUNCTION partition(array, low, high):\n  pivot = array[high]\n  i = low - 1\n  FOR j = low TO high - 1:\n    IF array[j] <= pivot:\n      i = i + 1\n      swap(array[i], array[j])\n  swap(array[i+1], array[high])\n  RETURN i + 1",
		"when_to_use": [
			"You need the fastest average performance on large random datasets.",
			"Memory is limited since it sorts in-place with only O(log n) stack space.",
			"Stability is not required.",
			"Cache performance matters since it accesses memory sequentially."
		],
		"real_world": "Quick Sort powers C's qsort(), C++ std::sort(), and many other standard libraries. Its excellent cache behavior and low overhead make it the fastest general-purpose sort on random data in practice.",
		"quick_comparison": "Quick Sort vs Merge Sort: Quick Sort is faster in practice with better cache behavior and in-place operation, but risks O(n²) on bad inputs. Merge Sort is slower on average but guarantees O(n log n) and stability."
	},
	"Heap Sort": {
		"tier": "ADVANCED", "tier_color": COL_ADV,
		"introduction": "Heap Sort uses a max-heap, a binary tree where every parent is larger than its children, to efficiently extract the maximum element repeatedly. It first builds this heap from the array, then extracts the max one by one placing each at the end. The result is a sorted array, all in-place.",
		"what_it_is": "Comparison-based, unstable, in-place sorting algorithm that uses the heap data structure. Combines Selection Sort's extract-max idea with a binary heap's O(log n) extraction efficiency. Guarantees O(n log n) in all cases with O(1) auxiliary space.",
		"core_concept": "A max-heap lets you find and remove the largest element in O(log n). By heapifying the array in O(n) and then extracting n times for O(n log n) total, you sort the array in-place without needing extra memory.",
		"how_it_works": [
			"Build a max-heap from the unsorted array by heapifying bottom-up.",
			"The root of the heap is now the maximum element.",
			"Swap the root with the last element of the heap.",
			"Reduce heap size by 1 since the last element is now in its final sorted position.",
			"Sift down the new root to restore the heap property.",
			"Repeat steps 2 through 5 until the heap has only one element."
		],
		"complexity": {"best": "O(n log n)", "average": "O(n log n)", "worst": "O(n log n)", "space": "O(1)"},
		"pseudocode": "FUNCTION heapSort(array):\n  n = length(array)\n  FOR i = n/2 - 1 DOWN TO 0:\n    heapify(array, n, i)\n  FOR i = n-1 DOWN TO 1:\n    swap(array[0], array[i])\n    heapify(array, i, 0)\n\nFUNCTION heapify(array, n, root):\n  largest = root\n  left = 2*root + 1\n  right = 2*root + 2\n  IF left < n AND array[left] > array[largest]:\n    largest = left\n  IF right < n AND array[right] > array[largest]:\n    largest = right\n  IF largest != root:\n    swap(array[root], array[largest])\n    heapify(array, n, largest)",
		"when_to_use": [
			"You need guaranteed O(n log n) with O(1) extra space, unlike Merge Sort.",
			"Memory is severely constrained but reliable performance is still required.",
			"A priority queue is needed as a by-product of the sort."
		],
		"real_world": "Heap Sort is used in real-time operating system schedulers. The underlying heap structure powers priority queues in Dijkstra's shortest path algorithm and OS task scheduling systems.",
		"quick_comparison": "Heap Sort vs Merge Sort: both guarantee O(n log n), but Heap Sort is in-place with O(1) space while Merge Sort needs O(n) extra memory. Merge Sort is stable and has better cache performance in practice."
	},
	"Tim Sort": {
		"tier": "ADVANCED", "tier_color": COL_ADV,
		"introduction": "Tim Sort is the real-world champion. It is the algorithm Python and Java actually use to sort your data. It was designed by Tim Peters in 2002 specifically to exploit patterns that appear in real data. It combines the speed of Merge Sort with the efficiency of Insertion Sort on small or partially-sorted runs, making it extraordinarily fast on data you would actually encounter in practice.",
		"what_it_is": "Hybrid stable comparison-based sorting algorithm derived from Merge Sort and Insertion Sort. Identifies naturally occurring sorted subsequences called runs, uses Insertion Sort to build runs up to a minimum size typically 32 to 64, then merges these runs using an optimized merge strategy. Requires O(n) auxiliary space.",
		"core_concept": "Real data is rarely random. It often contains sorted or reverse-sorted subsequences. Tim Sort finds these natural runs and exploits them. Short runs are extended with Insertion Sort which is fastest on nearly-sorted data, then all runs are merged bottom-up. The result is dramatically faster than pure Merge Sort on typical real-world inputs.",
		"how_it_works": [
			"Calculate minRun, typically 32 to 64, based on array size.",
			"Scan the array to find natural runs, ascending or descending sequences.",
			"If a run is descending, reverse it to make it ascending.",
			"If a run is shorter than minRun, extend it using Insertion Sort.",
			"Push each run's start and length onto a stack.",
			"Merge runs from the stack using a balanced merge strategy.",
			"Maintain invariants on the stack to ensure balanced merging.",
			"Repeat until the entire array is one merged run."
		],
		"complexity": {"best": "O(n)", "average": "O(n log n)", "worst": "O(n log n)", "space": "O(n)"},
		"pseudocode": "FUNCTION timSort(array):\n  minRun = calcMinRun(length(array))\n  FOR start = 0 TO n-1 STEP minRun:\n    end = min(start + minRun - 1, n-1)\n    insertionSort(array, start, end)\n  size = minRun\n  WHILE size < n:\n    FOR left = 0 TO n-1 STEP 2*size:\n      mid   = min(left + size - 1, n-1)\n      right = min(left + 2*size - 1, n-1)\n      IF mid < right:\n        merge(array, left, mid, right)\n    size = size * 2",
		"when_to_use": [
			"Sorting real-world data that contains partially sorted subsequences.",
			"You need a stable sort with the best practical performance.",
			"General-purpose sorting where you do not know the input distribution in advance.",
			"Any situation where Python's sorted() or Java's Arrays.sort() would be used."
		],
		"real_world": "Tim Sort is the default sorting algorithm in Python since version 2.3, Java for object arrays since Java 7, and Android's Java runtime. It is also used in GNU Octave and Swift's standard library, making it one of the most widely deployed sorting algorithms in existence.",
		"quick_comparison": "Tim Sort vs Merge Sort: Tim Sort is strictly better in practice. It adapts to existing order in the data giving O(n) on sorted input while Merge Sort always takes O(n log n) regardless, and Tim Sort's optimized merge strategy reduces overhead significantly."
	},
	"Shell Sort": {
		"tier": "ADVANCED", "tier_color": COL_ADV,
		"introduction": "Shell Sort fixes Insertion Sort's biggest weakness: it can only move elements one step at a time. Shell Sort starts by sorting elements that are far apart, then progressively closes the gap until a final Insertion Sort pass finishes the job. By the time the gap reaches 1, the array is nearly sorted and Insertion Sort runs in near-linear time.",
		"what_it_is": "Comparison-based, unstable, in-place generalization of Insertion Sort. Instead of comparing adjacent elements, it compares and inserts elements at a specified gap distance. The gap shrinks over multiple passes according to a chosen gap sequence. Time complexity depends on the gap sequence used, approximately O(n^1.3) empirically with Ciura's sequence.",
		"core_concept": "By sorting elements at large gaps first, Shell Sort moves small elements toward the front much faster than one-step-at-a-time Insertion Sort. Each reduction of the gap makes the array more sorted, so the final small-gap passes are cheap.",
		"how_it_works": [
			"Choose a gap sequence, common choices are n/2 halving or Ciura's sequence.",
			"Start with the largest gap value.",
			"Perform an Insertion Sort on elements that are gap positions apart.",
			"Reduce the gap to the next value in the sequence.",
			"Repeat steps 3 and 4 for each gap value.",
			"When gap equals 1, perform a final standard Insertion Sort on the nearly-sorted array."
		],
		"complexity": {"best": "O(n log n)", "average": "O(n log²n)", "worst": "O(n log²n)", "space": "O(1)"},
		"pseudocode": "FUNCTION shellSort(array):\n  n = length(array)\n  gap = n / 2\n  WHILE gap > 0:\n    FOR i = gap TO n-1:\n      temp = array[i]\n      j = i\n      WHILE j >= gap AND array[j - gap] > temp:\n        array[j] = array[j - gap]\n        j = j - gap\n      array[j] = temp\n    gap = gap / 2",
		"when_to_use": [
			"You need better-than-O(n²) performance without extra memory, unlike Merge Sort.",
			"The environment is memory-constrained and O(n) space algorithms are not viable.",
			"Embedded systems where recursive algorithms are problematic.",
			"Moderate-sized datasets where implementation simplicity is valued."
		],
		"real_world": "Shell Sort is used in uClib, a small C standard library for embedded Linux, and in the Linux kernel for certain small sorting tasks. Its combination of in-place operation and sub-quadratic performance makes it practical for firmware and microcontroller environments.",
		"quick_comparison": "Shell Sort vs Insertion Sort: Shell Sort is a strict improvement. Same in-place O(1) space characteristics, but significantly faster on larger arrays by pre-sorting at large gaps before the final insertion pass."
	}
}

var _modal_overlay: CanvasLayer
var _modal_vbox: VBoxContainer
var _modal_title: Label

func _ready() -> void:
	_modal_overlay = $CanvasLayer/ModalOverlay
	_modal_vbox    = $CanvasLayer/ModalOverlay/ModalPanel/ScrollContainer/VBoxContainer
	_modal_title   = $CanvasLayer/ModalOverlay/ModalPanel/ModalTitle
	_modal_overlay.visible = false

	$CanvasLayer/ModalOverlay/BgDim.gui_input.connect(_on_bg_dim_input)
	$CanvasLayer/ModalOverlay/ModalPanel/CloseBtn.pressed.connect(_close_modal)
	$CanvasLayer/HeaderPanel/BackBtn.pressed.connect(_on_back_pressed)

	var cards = $CanvasLayer/CardsContainer
	for child in cards.get_children():
		if child.has_node("CardBtn"):
			var btn: Button = child.get_node("CardBtn")
			var algo: String = child.get_meta("algo")
			btn.pressed.connect(_show_modal.bind(algo))

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_bg_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_modal()

func _show_modal(algo: String) -> void:
	_populate_modal(algo)
	_modal_overlay.visible = true
	var panel = $CanvasLayer/ModalOverlay/ModalPanel
	panel.modulate = Color(1, 1, 1, 0)
	var tw = create_tween()
	tw.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.2)

func _close_modal() -> void:
	_modal_overlay.visible = false

func _populate_modal(algo: String) -> void:
	for child in _modal_vbox.get_children():
		child.queue_free()

	var data: Dictionary = ALGO_DATA[algo]

	_modal_title.text = algo.to_upper()
	_modal_title.add_theme_color_override("font_color", data["tier_color"])

	_add_section("INTRODUCTION", data["introduction"], false)
	_add_divider()
	_add_section("WHAT IT IS", data["what_it_is"], false)
	_add_divider()
	_add_section("CORE CONCEPT", data["core_concept"], false)
	_add_divider()
	_add_numbered_section("HOW IT WORKS", data["how_it_works"])
	_add_divider()
	_add_complexity_table(data["complexity"])
	_add_divider()
	_add_pseudocode(data["pseudocode"])
	_add_divider()
	_add_bullet_section("WHEN TO USE IT", data["when_to_use"])
	_add_divider()
	_add_section("REAL-WORLD USAGE", data["real_world"], false)
	_add_divider()
	_add_section("QUICK COMPARISON", data["quick_comparison"], false)

func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", GOLD)
	return lbl

func _body_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", WHITE)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl

func _add_section(header: String, body: String, _unused: bool) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_section_label(header))
	vbox.add_child(_body_label(body))
	_modal_vbox.add_child(vbox)

func _add_numbered_section(header: String, items: Array) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_section_label(header))
	for i in items.size():
		vbox.add_child(_body_label(str(i + 1) + ".  " + items[i]))
	_modal_vbox.add_child(vbox)

func _add_bullet_section(header: String, items: Array) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_section_label(header))
	for item in items:
		vbox.add_child(_body_label("•  " + item))
	_modal_vbox.add_child(vbox)

func _add_divider() -> void:
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = GOLD_DIM
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_vbox.add_child(sep)

func _add_complexity_table(data: Dictionary) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_section_label("COMPLEXITY"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)

	var rows = [
		["Best Case", data["best"]],
		["Average Case", data["average"]],
		["Worst Case", data["worst"]],
		["Space", data["space"]]
	]
	for row in rows:
		var key := Label.new()
		key.text = row[0]
		key.add_theme_font_override("font", FONT)
		key.add_theme_font_size_override("font_size", 18)
		key.add_theme_color_override("font_color", DIM)
		grid.add_child(key)

		var val := Label.new()
		val.text = row[1]
		val.add_theme_font_override("font", FONT)
		val.add_theme_font_size_override("font_size", 18)
		val.add_theme_color_override("font_color", AMBER_TEXT)
		grid.add_child(val)

	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.09, 0.14, 1)
	sb.border_width_left = 3
	sb.border_color = GOLD_DIM
	sb.content_margin_left = 16
	sb.content_margin_top = 10
	sb.content_margin_right = 16
	sb.content_margin_bottom = 10
	bg.add_theme_stylebox_override("panel", sb)
	bg.add_child(grid)

	vbox.add_child(bg)
	_modal_vbox.add_child(vbox)

func _add_pseudocode(code: String) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_section_label("PSEUDOCODE"))

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_DARK
	sb.border_width_left = 3
	sb.border_color = Color(0.2, 0.6, 0.2, 1)
	sb.content_margin_left = 16
	sb.content_margin_top = 12
	sb.content_margin_right = 16
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = code
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", TERMINAL)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(lbl)

	vbox.add_child(panel)
	_modal_vbox.add_child(vbox)
