-- Signup email availability check RPC.
-- Allows client-side preflight duplicate checks without sending signup emails.

create or replace function public.rpc_check_signup_email_availability(p_email text)
returns table (
  is_available boolean
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  normalized_email text;
  email_exists boolean;
begin
  normalized_email := lower(trim(coalesce(p_email, '')));

  if normalized_email = '' then
    return query select false;
    return;
  end if;

  if normalized_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' then
    return query select false;
    return;
  end if;

  select exists (
    select 1
    from auth.users au
    where lower(coalesce(au.email, '')) = normalized_email
  ) into email_exists;

  return query select not email_exists;
end;
$$;

revoke all on function public.rpc_check_signup_email_availability(text) from public;
grant execute on function public.rpc_check_signup_email_availability(text) to anon, authenticated;
