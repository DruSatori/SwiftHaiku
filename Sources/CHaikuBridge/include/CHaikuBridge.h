// Thin C++ bridge from SwiftHaiku to libbe. Swift cannot import BApplication or BWindow (they are
// non-copyable, and attributes on them do not stick), cannot subclass them and cannot call their
// inherited members, so these subclasses are immortal foreign references whose own methods are
// the only calls Swift makes. All logic lives in Swift; this only builds native views.
#pragma once
#include <Application.h>
#include <String.h>
#include <Window.h>
#include <swift/bridging>
#include <vector>

class BGroupView;
class BTabView;

/// Receives a window's control events on the window thread, with the window locked.
/// @param context The pointer given to SHWindow::create.
/// @param id The id the control was added with.
/// @param text The new text of a text field or editor, or NULL for other controls. Valid only
/// during the call.
/// @param value The new value of a check box (0 or 1), picker or tab view (index), list (index,
/// -1 for none), slider or color control (0xRRGGBB00); else 0.
typedef void (*SHEventHandler)(void *context, int32_t id, const char *text, int32_t value);

/// The application object; create it before any window.
class SWIFT_IMMORTAL_REFERENCE SHApp : public BApplication {
public:
	/// @param signature MIME application signature, e.g. "application/x-vnd.me-counter".
	static SHApp *create(const char *signature) { return new SHApp(signature); }
	/// Runs the message loop until the app quits (here: when its window closes).
	void run() { Run(); }

private:
	SHApp(const char *signature) : BApplication(signature) {}
};

/// A titled window whose content is built from a stream of layout calls: beginContent(), then
/// stack, leaf and modifier calls, then endContent(). Content that keeps its structure is updated
/// in place with setViewText() instead. Closing it quits the app.
class SWIFT_IMMORTAL_REFERENCE SHWindow : public BWindow {
public:
	/// @param handler Called for every button press and text edit.
	/// @param context Passed back to handler; must outlive the window.
	static SHWindow *create(const char *title, SHEventHandler handler, void *context)
	{
		return new SHWindow(title, handler, context);
	}
	void show() { Show(); }

	/// Deletes the current content and starts a new top-level vertical group. Drawing is held
	/// off until endContent(), so the rebuild does not flash.
	void beginContent();
	/// Finishes the content; puts the keyboard focus and selection back into the text field
	/// that had them, found by id, and draws the new content.
	void endContent();
	/// Sets the text of a leaf view in place: a text's text, a button's title or a text field's
	/// or editor's text. Does nothing if it already has that text, so a caret and selection stay.
	/// @param index The view's position among the leaf views (every view an add call or
	/// beginTabs() made) added since beginContent(); texts are named "text<index>".
	void setViewText(int32_t index, const char *text);
	/// Sets the value of a leaf view in place, as in the matching add call: a check box's state,
	/// a picker's, list's or tab view's selection, a slider's value, a color or a progress bar's
	/// thousandths. Does nothing if it already has that value, or for a negative tab selection.
	/// @param index As for setViewText().
	void setViewValue(int32_t index, int32_t value);
	/// Starts a nested BGroupView. @param spacing Points between items; negative for the default.
	void beginStack(bool vertical, float spacing);
	/// Ends the innermost stack or group box.
	void endStack();
	/// Starts a BBox with a title around a nested vertical BGroupView; end it with endStack().
	void beginBox(const char *title);
	/// Starts a vertical BGroupView scrolled vertically in a BScrollView; end it with
	/// endStack(). Give it a height with setLastSize(), or it grows to fit its content.
	void beginScroll();
	/// Starts a BTabView, which counts as a leaf view; end it with endTabs(). Every tab view
	/// stays constructed (the hidden ones are only hidden), so leaf indexes do not depend on
	/// the selection. @param selection The tab to show; negative to keep the current one.
	/// @param id Reported when the user picks a tab; negative to report nothing.
	void beginTabs(int32_t selection, int32_t id);
	/// Starts a tab of the innermost tab view: a vertical BGroupView; end it with endStack().
	void beginTab(const char *title);
	/// Ends the innermost tab view and shows its selected tab.
	void endTabs();
	/// Sets the insets of the current group. @param insets Points; negative for the default.
	void setInsets(float insets);
	void addText(const char *text);
	/// Adds a BButton named "button<id>".
	void addButton(const char *title, int32_t id);
	/// Adds a BTextControl named "field<id>". @param label Shown left of the field; may be empty.
	/// @param secure Hides the typed text.
	void addTextField(const char *label, const char *text, bool secure, int32_t id);
	/// Adds a BCheckBox named "toggle<id>".
	void addToggle(const char *title, bool on, int32_t id);
	/// Adds a picker named "picker<id>": a BMenuField with a pop-up menu, or a vertical
	/// BGroupView with the title (if any) and one BRadioButton per option.
	/// @param options The option titles, separated by newlines.
	void addPicker(const char *title, const char *options, int32_t selection, bool radio,
		int32_t id);
	/// Adds a horizontal BSlider named "slider<id>" with values from 0 to steps.
	void addSlider(int32_t value, int32_t steps, int32_t id);
	/// Adds a BTextView named "field<id>" in a BScrollView, reported like a text field.
	void addTextEditor(const char *text, int32_t id);
	/// Adds a BListView named "list<id>" in a BScrollView. @param items The item titles,
	/// separated by newlines. @param selection The selected item; negative for none.
	void addList(const char *items, int32_t selection, int32_t id);
	/// Adds the title, if any, as a text that is not a leaf view, then a BColorControl named
	/// "color<id>". @param rgb The color as 0xRRGGBB00.
	void addColorPicker(const char *title, int32_t rgb, int32_t id);
	/// Adds a BStatusBar. @param value Progress in thousandths.
	void addProgress(const char *title, int32_t value);
	/// Adds a BSeparatorView across the current group: a horizontal line in a vertical group.
	void addDivider();
	/// Adds glue that takes up the free space in the current group.
	void addSpacer();
	/// Fixes the size of the item added last. @param width, height Points; negative leaves it free.
	void setLastSize(float width, float height);

private:
	SHWindow(const char *title, SHEventHandler handler, void *context);
	void MessageReceived(BMessage *message) override;
	void addLeaf(BView *view);
	BView *leafAt(int32 index) const;

	SHEventHandler fHandler;
	void *fContext;
	BGroupView *fContent = nullptr;
	std::vector<BGroupView *> fStack;
	std::vector<BTabView *> fTabs;
	std::vector<BView *> fViews; // the leaf views, in the order they were added
	BString fFocusName;
	int32 fSelectionStart = 0;
	int32 fSelectionEnd = 0;
};
