# GdUnit TestSuite that keeps the documentation mechanically honest.
#
# Docs drift silently: a script gets renamed, the prose keeps describing the old
# path, and an agent following the docs reads a fiction and edits the wrong file.
# Before this suite, `docs/systems/*` carried ~91 backticked paths that did not
# resolve, and the `docs/systems` index was a hand-maintained copy of a directory
# listing that could only ever rot.
#
# What is enforced:
#   1. Every project path a live doc backticks must resolve under `res://`.
#      Paths are repo-root-relative, so this also enforces the `src/` prefix -
#      `Systems/stats/stats.gd` fails, `src/Systems/stats/stats.gd` passes.
#   2. Every bare filename a live doc backticks must exist somewhere in the
#      project, so a renamed script is caught even when cited by basename.
#   3. The index in `docs/ai_overview.md` must list every doc that exists, so
#      adding a doc without indexing it fails the build instead of hiding.
#
# `docs/archive/` is deliberately NOT checked. Those are frozen implementation
# logs for work that already shipped, kept for provenance only. Rewriting their
# contents to satisfy this suite would falsify the historical record, so they are
# excluded from both the link walk and the index.
#
# Known limits, accepted on purpose:
#   - Templated spans are skipped: `res://src/Assets/stats/%s.png`,
#     `src/Assets/weapons/<id>.png`, `docs/systems/*`. They are patterns, not
#     literal paths, and cannot be resolved.
#   - A directory cited with no extension and no `src/`-style root (e.g. a bare
#     `Nodes/Enemies`) is not machine-checked, because the same shape is used for
#     non-path prose (`flat/percent stats`). The root-prefix convention is what
#     makes the rest checkable.
class_name DocLinksTest
extends GdUnitTestSuite

## Root-relative docs that live outside `docs/`.
const ROOT_DOCS := ["res://AGENTS.md", "res://CONTEXT.md", "res://README.md"]
## Every `.md` under here is checked, except `docs/archive/`.
const DOCS_DIR := "res://docs"
const ARCHIVE_DIR := "res://docs/archive"
## The doc that must carry the index of `docs/systems/` and `docs/adr/`.
const INDEX_DOC := "res://docs/ai_overview.md"
## Root the fuzzy test runner resolves its argument against.
const TEST_ROOT := "res://test/"

## Extensions that make a backticked token a file reference.
const EXTS := [
	"gd", "tscn", "tres", "png", "jpg", "jpeg", "svg", "webp",
	"json", "cfg", "import", "md", "bat", "uid",
]

## First path segment values that mark a token as a project path. Requiring one
## of these is what lets the suite reject `Systems/...` (missing `src/`) while
## ignoring prose like `flat/percent`.
const ROOTS := ["res://", "src/", "test/", "docs/", "addons/", "reports/"]

## Bare filenames that are naming templates, not real files. Delete an entry when
## the file it stands in for actually exists.
const ALLOWED_BARE := {
	"XxxModifier.tscn": "template used by the 'add a modifier' checklist",
	"SomethingModifier.tscn": "template used by the naming-convention rule",
	"snake_case.png": "template used by the asset naming rule",
	"snake_case_modifier.gd": "template used by the modifier naming rule",
	"armormodifier.png": "visual_style.md names this as the icon a typo'd file should have",
	"poisonmodifier.png": "visual_style.md names this as the icon a scene still lacks",
}

## Project paths a doc names as "to be written". Delete an entry once the file
## lands and the suite will hold it to the real thing from then on.
const ALLOWED_MISSING := {
	"res://test/Systems/weapon/test_weapon_power_budget.gd":
		"balance.md prescribes this suite in its [PROPOSED] new-weapon checklist",
	"res://scene_shot.png":
		"runtime output of run_scene_shot.bat, written on demand, never committed",
}

var _basenames := {}


func before_test() -> void:
	_basenames = {}
	_walk("res://", _basenames)


# --- 1. project paths resolve -------------------------------------------------


func test_scanner_actually_finds_references() -> void:
	# Guards the other tests against a vacuous pass. If the span or token
	# extraction ever breaks, every link check below would "pass" by finding
	# nothing at all. That is not hypothetical: an alternation joined with ", "
	# instead of "|" made this suite match zero paths and report green.
	assert_array(_tokens("src/Systems/stats/stats.gd")).has_size(1)
	# Prose that merely contains a slash must not be mistaken for a path.
	assert_array(_tokens("flat/percent stats")).is_empty()
	# A templated span is a pattern, not a literal, so it is skipped whole.
	assert_array(_tokens("res://src/Assets/stats/%s.png")).is_empty()
	assert_int(_live_docs().size()).override_failure_message(
		"the live doc set collapsed - is docs/ still where it belongs?"
	).is_greater(10)
	var tokens := 0
	for doc in _live_docs():
		for span in _spans(_read(doc)):
			tokens += _tokens(span).size()
	assert_int(tokens).override_failure_message(
		"only %d path references found across the docs; the scanner is broken"
		% tokens).is_greater(100)


func test_backticked_project_paths_resolve() -> void:
	var broken := PackedStringArray()
	for doc in _live_docs():
		var text := _read(doc)
		for span in _spans(text):
			for token in _tokens(span):
				# A bare filename is checked by test_bare_filenames_exist_somewhere,
				# which resolves it anywhere in the project instead of demanding a
				# full path.
				if not token.contains("/"):
					continue
				var res_path := _resolve(token)
				if res_path == "" or res_path in ALLOWED_MISSING:
					continue
				if not _exists(res_path):
					broken.append("%s -> %s" % [doc.get_file(), token])
	var message := "Unresolvable project paths in the docs. Fix the path, or delete it"
	message += " if the thing it names is gone. Repo-root-relative means the `src/`"
	message += " prefix is required: `src/Systems/stats/stats.gd`, not"
	message += " `Systems/stats/stats.gd`."
	message += "\nBroken (%d):\n  %s" % [broken.size(), "\n  ".join(broken)]
	assert_array(broken).override_failure_message(message).is_empty()


# --- 2. bare filenames still exist -------------------------------------------


func test_bare_filenames_exist_somewhere() -> void:
	var missing := PackedStringArray()
	# Both allowlists mean the same thing - a name a doc cites that is
	# deliberately not on disk - so both apply here.
	var excused := ALLOWED_BARE.duplicate()
	for path in ALLOWED_MISSING:
		excused[path.get_file()] = "documented as not-yet-written"
	for doc in _live_docs():
		var text := _read(doc)
		for span in _spans(text):
			for token in _tokens(span):
				if token.contains("/") or token.begins_with("res://"):
					continue
				var base := token.get_file()
				if base in excused or base in _basenames:
					continue
				missing.append("%s -> %s" % [doc.get_file(), token])
	assert_array(missing).override_failure_message(
		"Doc cites a bare filename that no longer exists anywhere in the project."
		+ " If the file was renamed, cite its new path; if it was deleted, drop the"
		+ " sentence."
		+ "\nMissing (%d):\n  %s"
		% [missing.size(), "\n  ".join(missing)]).is_empty()


# --- 3. the index lists every doc --------------------------------------------


func test_index_lists_every_systems_doc() -> void:
	assert_indexed("res://docs/systems")


func test_index_lists_every_adr() -> void:
	assert_indexed("res://docs/adr")


func test_index_does_not_list_archived_plans_as_live() -> void:
	# The finished implementation logs moved from docs/plans/ to docs/archive/.
	# Nothing should point at the old tree, so this fails if the index was not
	# updated in the same change that retired it.
	var index := _read(INDEX_DOC)
	assert_bool(index.contains("docs/plans/")).override_failure_message(
		"ai_overview.md still points at docs/plans/, which was retired to docs/archive/"
	).is_false()


# --- helpers ------------------------------------------------------------------


func assert_indexed(dir_path: String) -> void:
	var index := _read(INDEX_DOC)
	var unlisted := PackedStringArray()
	for file_name in _list_md(dir_path):
		if not index.contains(file_name):
			unlisted.append(file_name)
	var message := "%s has docs that docs/ai_overview.md does not index. Add a row" % dir_path
	message += " to the index table there, or the doc is invisible to anyone starting"
	message += " from ai_overview.md."
	message += "\nUnlisted (%d):\n  %s" % [unlisted.size(), "\n  ".join(unlisted)]
	assert_array(unlisted).override_failure_message(message).is_empty()


## Every `.md` the suite is responsible for: the root docs plus `docs/`, minus
## the archive.
func _live_docs() -> PackedStringArray:
	var out := PackedStringArray(ROOT_DOCS)
	for file_name in _list_md(DOCS_DIR):
		var full := DOCS_DIR.path_join(file_name)
		if not full.begins_with(ARCHIVE_DIR):
			out.append(full)
	return out


## `.md` files under `base`, recursively, as paths relative to it. `skip` prunes
## a subtree by path prefix, which is what keeps the archive out of the live set.
## `current` is the recursion cursor and always starts at `base`.
func _list_md(base: String, current := "", skip := "") -> PackedStringArray:
	var out := PackedStringArray()
	var here := current if current != "" else base
	var prefix := base.trim_suffix("/") + "/"
	var dir := DirAccess.open(here)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := here.path_join(entry)
			if dir.current_is_dir():
				if skip == "" or not full.begins_with(skip):
					out.append_array(_list_md(base, full, skip))
			elif entry.ends_with(".md"):
				out.append(full.trim_prefix(prefix))
		entry = dir.get_next()
	dir.list_dir_end()
	return out


## Backticked spans, which is where every path reference in these docs lives.
## Fenced code blocks are not backticked, so command examples are not scanned.
func _spans(text: String) -> PackedStringArray:
	var rx := RegEx.new()
	rx.compile("`([^`\\n]+)`")
	var out := PackedStringArray()
	for m in rx.search_all(text):
		out.append(m.get_string(1))
	return out


## Path-looking tokens inside one backticked span. A span holding a template
## placeholder is skipped wholesale, because none of its tokens are literal.
func _tokens(span: String) -> PackedStringArray:
	for marker in ["%", "*", "<", ">", "(", ")"]:
		if span.contains(marker):
			return PackedStringArray()
	var pattern := "[A-Za-z0-9_][A-Za-z0-9_./\\\\-]*\\.(?:%s)\\b" % "|".join(EXTS)
	var rx := RegEx.new()
	rx.compile(pattern)
	var out := PackedStringArray()
	for m in rx.search_all(span):
		var token := m.get_string().replace("\\", "/")
		# A leading `.\` is how the docs spell "run this from the repo root".
		if token.begins_with("./"):
			token = token.substr(2)
		if _is_project_path(token):
			out.append(token)
	return out


## A token counts as a project path when it is absolute (`res://`), starts at a
## known repo root, or carries a known file extension. That last clause is what
## catches `Systems/stats/stats.gd`; the root clause is what keeps prose like
## `flat/percent stats` out of the results.
func _is_project_path(token: String) -> bool:
	for root in ROOTS:
		if token.begins_with(root):
			return true
	return token.get_extension() in EXTS


## Repo-relative or absolute token to a `res://` path, or "" if not checkable.
func _resolve(token: String) -> String:
	if token.begins_with("res://"):
		return token
	return "res://" + token


func _exists(res_path: String) -> bool:
	if FileAccess.file_exists(res_path) or DirAccess.open(res_path) != null:
		return true
	# `run_tests_gdunit_custom.bat` resolves its argument against res://test, so
	# the runner examples in AGENTS.md cite suite paths relative to that root
	# rather than to the repo. Accepting that shape here keeps the examples
	# copy-pasteable instead of forcing a path the runner would not accept.
	return FileAccess.file_exists(TEST_ROOT + res_path.trim_prefix("res://"))


func _read(res_path: String) -> String:
	if not FileAccess.file_exists(res_path):
		return ""
	return FileAccess.get_file_as_string(res_path)


## Collect every file's basename, for the bare-filename check. Dot-directories
## are skipped so `.godot/`'s import cache does not dominate the walk.
func _walk(path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := path.path_join(entry)
			if dir.current_is_dir():
				_walk(full, out)
			else:
				out[full.get_file()] = full
		entry = dir.get_next()
	dir.list_dir_end()
