# EasyMail for WoW: Forever

An unofficial port of [EasyMail](https://www.curseforge.com/wow/addons/easymail) by **Yarko** to the World of Warcraft: Forever client (interface 16001).

All credit for EasyMail goes to Yarko. This repo only adds the changes needed for it to run on Forever. It's based on EasyMail 5.2.1, and the first commit is the unmodified original, so `git diff HEAD~1` shows exactly what changed.

## Why it needed changes

Forever uses a rewritten version of the Retail mail window. Several global functions EasyMail relies on, such as `InboxFrame_Update`, `OpenMail_Update`, `OpenMail_Delete` and the inbox page buttons, were moved onto the mail frames themselves. On Forever, the original addon errors at login, and the Mark/Clear buttons and per-mail checkboxes don't work.

## Changes

- Adds `16001` to the TOC's `## Interface:` line.
- Uses Forever's inbox refresh, open-mail refresh and delete when the old global functions aren't present. Other clients keep using the originals.
- Hooks the inbox and open-mail refresh on the frames themselves when the global functions don't exist.
- Uses Forever's new names for the Prev/Next page buttons.
- Treats Forever as Retail for layout, so the Classic-only edit-box code isn't used there.
- Uses `ChatFrameUtil.FocusActiveWindow` when it exists, for the Add Name popup.
- Adds to the mail frame's OnShow behaviour instead of replacing it.
- Only repositions the Take All button when a valid mail is open, so the open-mail text area doesn't shrink after every inbox refresh.

## Install

Copy the `EasyMail` folder into `World of Warcraft/_forever_/Interface/AddOns/`.

## License

The original EasyMail ships without a license, so Yarko keeps all rights to it. This port is shared for convenience with credit to the author. If Yarko would like it taken down, open an issue and it will be removed.
