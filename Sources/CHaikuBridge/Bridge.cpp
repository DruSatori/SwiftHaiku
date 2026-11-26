#include "CHaikuBridge.h"

#include <Box.h>
#include <Button.h>
#include <CheckBox.h>
#include <GroupLayout.h>
#include <GroupView.h>
#include <MenuField.h>
#include <MenuItem.h>
#include <PopUpMenu.h>
#include <RadioButton.h>
#include <SeparatorView.h>
#include <Slider.h>
#include <SpaceLayoutItem.h>
#include <StatusBar.h>
#include <StringList.h>
#include <StringView.h>
#include <TextControl.h>

#include <string.h>

static const uint32 kButtonPressed = 'shBt';
static const uint32 kTextModified = 'shTx';
static const uint32 kValueChanged = 'shVl';

/// A view name made of a kind and a control id, e.g. "field3", for FindView() and scripting.
static BString
nameFor(const char *kind, int32 id)
{
	BString name;
	name.SetToFormat("%s%" B_PRId32, kind, id);
	return name;
}


/// A message reporting a control's new value; radio buttons and menu items carry theirs in
/// "value", other controls get it as "be:value" from BControl::Invoke().
static BMessage *
valueMessage(int32 id, int32 value = -1)
{
	BMessage *message = new BMessage(kValueChanged);
	message->AddInt32("id", id);
	if (value >= 0)
		message->AddInt32("value", value);
	return message;
}


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
	DisableUpdates();
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
	fViews.clear();
}


void
SHWindow::endContent()
{
	fStack.clear();
	BTextControl *field = fFocusName.IsEmpty() ? NULL
		: dynamic_cast<BTextControl *>(FindView(fFocusName));
	if (field != NULL) {
		field->MakeFocus(true);
		field->TextView()->Select(fSelectionStart, fSelectionEnd);
	}
	EnableUpdates();
}


void
SHWindow::setViewText(int32_t index, const char *text)
{
	if (index < 0 || (size_t)index >= fViews.size())
		return;
	BView *view = fViews[index];
	// BTextControl is a BControl too, so it must be tried first.
	if (BTextControl *field = dynamic_cast<BTextControl *>(view)) {
		if (strcmp(field->Text(), text) != 0)
			field->SetText(text);
	} else if (BControl *control = dynamic_cast<BControl *>(view)) {
		if (strcmp(control->Label() ? control->Label() : "", text) != 0)
			control->SetLabel(text);
	} else if (BStringView *string = dynamic_cast<BStringView *>(view)) {
		if (strcmp(string->Text() ? string->Text() : "", text) != 0)
			string->SetText(text);
	}
}


void
SHWindow::setViewValue(int32_t index, int32_t value)
{
	if (index < 0 || (size_t)index >= fViews.size())
		return;
	BView *view = fViews[index];
	if (BMenuField *field = dynamic_cast<BMenuField *>(view)) {
		BMenuItem *item = field->Menu()->ItemAt(value);
		if (item != NULL && !item->IsMarked())
			item->SetMarked(true);
	} else if (BStatusBar *bar = dynamic_cast<BStatusBar *>(view)) {
		if (bar->CurrentValue() != value)
			bar->SetTo(value);
	} else if (BControl *control = dynamic_cast<BControl *>(view)) {
		if (control->Value() != value)
			control->SetValue(value);
	} else if (BGroupView *group = dynamic_cast<BGroupView *>(view)) {
		// A radio picker: turning one button on turns its siblings off.
		for (int32 i = 0, radio = 0; BView *child = group->ChildAt(i); i++) {
			BRadioButton *button = dynamic_cast<BRadioButton *>(child);
			if (button != NULL && radio++ == value && button->Value() == 0)
				button->SetValue(1);
		}
	}
}


void
SHWindow::addLeaf(BView *view)
{
	fStack.back()->GroupLayout()->AddView(view);
	fViews.push_back(view);
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
SHWindow::beginBox(const char *title)
{
	BGroupView *group = new BGroupView(B_VERTICAL);
	group->GroupLayout()->SetInsets(B_USE_DEFAULT_SPACING);
	BBox *box = new BBox(B_FANCY_BORDER, group);
	box->SetLabel(title);
	fStack.back()->GroupLayout()->AddView(box);
	fStack.push_back(group);
}


void
SHWindow::setInsets(float insets)
{
	fStack.back()->GroupLayout()->SetInsets(spacingOrDefault(insets));
}


void
SHWindow::addText(const char *text)
{
	addLeaf(new BStringView(nameFor("text", fViews.size()), text));
}


void
SHWindow::addButton(const char *title, int32_t id)
{
	BMessage *message = new BMessage(kButtonPressed);
	message->AddInt32("id", id);
	addLeaf(new BButton(nameFor("button", id), title, message));
}


void
SHWindow::addTextField(const char *label, const char *text, bool secure, int32_t id)
{
	BTextControl *field = new BTextControl(nameFor("field", id), label[0] != '\0' ? label : NULL,
		"", NULL);
	field->TextView()->HideTyping(secure); // before the text, which HideTyping() clears
	field->SetText(text);
	// Set after the initial text, so building the field does not report an edit.
	BMessage *message = new BMessage(kTextModified);
	message->AddInt32("id", id);
	field->SetModificationMessage(message);
	addLeaf(field);
}


void
SHWindow::addToggle(const char *title, bool on, int32_t id)
{
	BCheckBox *box = new BCheckBox(nameFor("toggle", id), title, valueMessage(id));
	box->SetValue(on);
	addLeaf(box);
}


void
SHWindow::addPicker(const char *title, const char *options, int32_t selection, bool radio,
	int32_t id)
{
	BStringList titles;
	BString(options).Split("\n", false, titles);
	if (radio) {
		BGroupView *group = new BGroupView(nameFor("picker", id), B_VERTICAL, 0);
		if (title[0] != '\0')
			group->GroupLayout()->AddView(new BStringView(NULL, title));
		for (int32 i = 0; i < titles.CountStrings(); i++) {
			BRadioButton *button = new BRadioButton(NULL, titles.StringAt(i), valueMessage(id, i));
			button->SetValue(i == selection);
			group->GroupLayout()->AddView(button);
		}
		addLeaf(group);
		return;
	}
	BPopUpMenu *menu = new BPopUpMenu("");
	for (int32 i = 0; i < titles.CountStrings(); i++) {
		BMenuItem *item = new BMenuItem(titles.StringAt(i), valueMessage(id, i));
		item->SetMarked(i == selection);
		menu->AddItem(item);
	}
	menu->SetTargetForItems(this);
	addLeaf(new BMenuField(nameFor("picker", id), title[0] != '\0' ? title : NULL, menu));
}


void
SHWindow::addSlider(int32_t value, int32_t steps, int32_t id)
{
	BSlider *slider = new BSlider(nameFor("slider", id), NULL, valueMessage(id), 0, steps,
		B_HORIZONTAL);
	slider->SetValue(value);
	// Also report while dragging, so views bound to the value follow the thumb.
	slider->SetModificationMessage(valueMessage(id));
	addLeaf(slider);
}


void
SHWindow::addProgress(const char *title, int32_t value)
{
	BStatusBar *bar = new BStatusBar(NULL, title[0] != '\0' ? title : NULL);
	bar->SetMaxValue(1000);
	bar->SetTo(value);
	addLeaf(bar);
}


void
SHWindow::addDivider()
{
	bool vertical = fStack.back()->GroupLayout()->Orientation() == B_VERTICAL;
	addLeaf(new BSeparatorView(vertical ? B_HORIZONTAL : B_VERTICAL));
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
			fHandler(fContext, id, NULL, 0);
			break;
		case kValueChanged:
			fHandler(fContext, id, NULL,
				message->GetInt32("value", message->GetInt32("be:value", 0)));
			break;
		case kTextModified:
		{
			// Edits are posted, so the field that sent this may be gone by now: look the id up
			// in the current content and report its text as it is now.
			if (BTextControl *field = dynamic_cast<BTextControl *>(FindView(nameFor("field", id))))
				fHandler(fContext, id, field->Text(), 0);
			break;
		}
		default:
			BWindow::MessageReceived(message);
	}
}
