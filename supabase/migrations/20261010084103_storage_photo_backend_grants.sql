-- Storage checks RLS as the caller, then commits the object as its backend role.
-- The backend only needs to read and lock the reservation, not edit its identity.
grant select, update(state) on public.memory_photos to service_role;
