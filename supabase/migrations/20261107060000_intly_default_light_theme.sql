-- Intly: light mode is the default for everyone, whatever the phone's setting.
-- Existing 'system' preferences become 'light'. Only 'light' and 'dark' remain.

update public.user_settings set theme = 'light' where theme = 'system';

alter table public.user_settings alter column theme set default 'light';

alter table public.user_settings drop constraint if exists user_settings_theme_check;
alter table public.user_settings
  add constraint user_settings_theme_check check (theme in ('light', 'dark'));
