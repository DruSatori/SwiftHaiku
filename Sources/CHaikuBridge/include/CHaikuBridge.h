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

/// Receives a window's control events on the window thread, with the window locked.
/// @param context The pointer given to SHWindow::create.
/// @param id The id the control was added with.
/// @param text The text field's new text, or NULL for a button press. Valid only during the call.
typedef void (*SHEventHandler)(void *context, int32_t id, const char *text);

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
	/// text. Does nothing if it already has that text, so a field's caret and selection stay.
	/// @param index The view's position among the leaf views added since beginContent().
	void setViewText(int32_t index, const char *text);
	/// Starts a nested BGroupView. @param spacing Points between items; negative for the default.
	void beginStack(bool vertical, float spacing);
	void endStack();
	/// Sets the insets of the current group. @param insets Points; negative for the default.
	void setInsets(float insets);
	void addText(const char *text);
	/// Adds a BButton named "button<id>".
	void addButton(const char *title, int32_t id);
	/// Adds a BTextControl named "field<id>". @param label Shown left of the field; may be empty.
	void addTextField(const char *label, const char *text, int32_t id);
	/// Adds glue that takes up the free space in the current group.
	void addSpacer();
	/// Fixes the size of the item added last. @param width, height Points; negative leaves it free.
	void setLastSize(float width, float height);

private:
	SHWindow(const char *title, SHEventHandler handler, void *context);
	void MessageReceived(BMessage *message) override;

	SHEventHandler fHandler;
	void *fContext;
	BGroupView *fContent = nullptr;
	std::vector<BGroupView *> fStack;
	std::vector<BView *> fViews; // the leaf views, in the order they were added
	BString fFocusName;
	int32 fSelectionStart = 0;
	int32 fSelectionEnd = 0;
};
