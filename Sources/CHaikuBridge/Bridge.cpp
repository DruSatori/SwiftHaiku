#include "CHaikuBridge.h"

#include <Button.h>
#include <GroupLayout.h>
#include <GroupView.h>
#include <SpaceLayoutItem.h>
#include <StringView.h>
#include <TextControl.h>

static const uint32 kButtonPressed = 'shBt';
static const uint32 kTextModified = 'shTx';

static float
spacingOrDefault(float value)
{
	return value < 0 ? B_USE_DEFAULT_SPACING : value;
}


SHWindow::SHWindow(const char *title, SHEventHandler handler, void *context)
	: BWindow(BRect(100, 100, 400, 260), title, B_TITLED_WINDOW,
		B_QUIT_ON_WINDOW_CLOSE | B_AUTO_UPDATE_SIZE_LIMITS),
	  fHandler(handler), fContext(context)
{
	SetLayout(new BGroupLayout(B_VERTICAL, 0));
}


void
SHWindow::beginContent()
{
	fFocusName = "";
	BView *focus = CurrentFocus();
	if (focus != NULL && dynamic_cast<BTextControl *>(focus->Parent()) != NULL) {
		static_cast<BTextView *>(focus)->GetSelection(&fSelectionStart, &fSelectionEnd);
		fFocusName = focus->Parent()->Name();
	}
	if (fContent != NULL) {
		RemoveChild(fContent);
		delete fContent;
	}
	fContent = new BGroupView(B_VERTICAL, 0);
	AddChild(fContent);
	fStack.assign(1, fContent);
}


void
SHWindow::endContent()
{
	fStack.clear();
	if (fFocusName.IsEmpty())
		return;
	if (BTextControl *field = dynamic_cast<BTextControl *>(FindView(fFocusName))) {
		field->MakeFocus(true);
		field->TextView()->Select(fSelectionStart, fSelectionEnd);
	}
}


void
SHWindow::beginStack(bool vertical, float spacing)
{
	BGroupView *group = new BGroupView(vertical ? B_VERTICAL : B_HORIZONTAL,
		spacingOrDefault(spacing));
	fStack.back()->GroupLayout()->AddView(group);
	fStack.push_back(group);
}


void
SHWindow::endStack()
{
	fStack.pop_back();
}


void
SHWindow::setInsets(float insets)
{
	fStack.back()->GroupLayout()->SetInsets(spacingOrDefault(insets));
}


void
SHWindow::addText(const char *text)
{
	fStack.back()->GroupLayout()->AddView(new BStringView(NULL, text));
}


void
SHWindow::addButton(const char *title, int32_t id)
{
	BMessage *message = new BMessage(kButtonPressed);
	message->AddInt32("id", id);
	BString name;
	name.SetToFormat("button%" B_PRId32, id);
	fStack.back()->GroupLayout()->AddView(new BButton(name, title, message));
}


void
SHWindow::addTextField(const char *label, const char *text, int32_t id)
{
	BString name;
	name.SetToFormat("field%" B_PRId32, id);
	BTextControl *field = new BTextControl(name, label[0] != '\0' ? label : NULL, text, NULL);
	// Set after the initial text, so building the field does not report an edit.
	BMessage *message = new BMessage(kTextModified);
	message->AddInt32("id", id);
	field->SetModificationMessage(message);
	fStack.back()->GroupLayout()->AddView(field);
}


void
SHWindow::addSpacer()
{
	fStack.back()->GroupLayout()->AddItem(BSpaceLayoutItem::CreateGlue());
}


void
SHWindow::setLastSize(float width, float height)
{
	BGroupLayout *layout = fStack.back()->GroupLayout();
	if (BLayoutItem *item = layout->ItemAt(layout->CountItems() - 1)) {
		item->SetExplicitSize(BSize(width < 0 ? B_SIZE_UNSET : width,
			height < 0 ? B_SIZE_UNSET : height));
	}
}


void
SHWindow::MessageReceived(BMessage *message)
{
	int32 id = message->GetInt32("id", -1);
	switch (message->what) {
		case kButtonPressed:
			fHandler(fContext, id, NULL);
			break;
		case kTextModified:
		{
			// Edits are posted, so the field that sent this may be gone by now: look the id up
			// in the current content and report its text as it is now.
			BString name;
			name.SetToFormat("field%" B_PRId32, id);
			if (BTextControl *field = dynamic_cast<BTextControl *>(FindView(name)))
				fHandler(fContext, id, field->Text());
			break;
		}
		default:
			BWindow::MessageReceived(message);
	}
}
