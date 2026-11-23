# LEVEL UP account + friends setup

The task UI, completion sound, centered check button, task hiding, and task deletion work without a backend. Cloud accounts and cross-device friends require a Supabase project; a static GitHub Pages site cannot create shared accounts or search other players by itself.

## 1. Create the Supabase project

1. Create a project at https://supabase.com/.
2. In the Supabase dashboard, open **Project Settings → API**.
3. Copy the **Project URL** and the **anon / publishable key**. Never use or publish the `service_role` key.
4. In `index.html`, find `SUPABASE_URL` and `SUPABASE_ANON_KEY` near the top of the main script. Replace the two placeholder strings with those values.

## 2. Create the database tables

1. In Supabase, open **SQL Editor → New query**.
2. Open `supabase_setup.sql` from this ZIP, copy all of it, and paste it into the SQL editor.
3. Press **Run** once. This creates the save, profile, friend-request, and friendship tables plus their access rules.

## 3. Set the website URL for email confirmation

In Supabase, open **Authentication → URL Configuration**. Set the Site URL to:

`https://appmaker7.github.io/Level-Up/`

Add that same address to the Redirect URLs list. Account creation may send a confirmation email before the first login, depending on the project's email-confirmation setting.

## Notes

- Pick a username that does not reveal personal information. Usernames are searchable by other signed-in players.
- Guest mode remains local to the current browser/device. Friends and cloud saves require an account.
- Keep the Supabase `service_role` secret private. The browser app should contain only the anon/publishable key.
