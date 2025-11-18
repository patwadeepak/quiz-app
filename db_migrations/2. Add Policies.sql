-- add owner to quiz table
alter table quizzes add column if not exists owner uuid;


/* --- Add per-row owner/user fields so policies can enforce ownership --- */

/* --- Triggers to populate owner/user_id from auth.uid() --- */
create or replace function public.set_quiz_owner()
returns trigger as $$
begin
  if new.owner is null then
    new.owner := auth.uid()::uuid;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists set_quiz_owner on quizzes;
create trigger set_quiz_owner
  before insert on quizzes
  for each row execute function public.set_quiz_owner();

/* --- Recommended RLS policies --- */

/* Quizzes: public read, authenticated insert/update/delete only for owner */
alter table quizzes enable row level security;

create policy "quizzes_public_select"
  on quizzes for select to authenticated using (owner = auth.uid()::uuid);

create policy "quizzes_insert_authenticated"
  on quizzes for insert to authenticated with check (owner = auth.uid()::uuid);

create policy "quizzes_update_owner"
  on quizzes for update to authenticated using (owner = auth.uid()::uuid) with check (owner = auth.uid()::uuid);

create policy "quizzes_delete_owner"
  on quizzes for delete to authenticated using (owner = auth.uid()::uuid);

/* Questions: allow reads publicly, and modifications only if parent quiz is owned by requester */
alter table questions enable row level security;

create policy "questions_public_select"
  on questions for select to authenticated using (
    exists (select 1 from quizzes q where q.id = questions.quiz_id and q.owner = auth.uid()::uuid)
  );

create policy "questions_insert_if_quiz_owner"
  on questions for insert to authenticated with check (
    exists (select 1 from quizzes q where q.id = questions.quiz_id and q.owner = auth.uid()::uuid)
  );

create policy "questions_modify_if_quiz_owner"
  on questions for update to authenticated using (
    exists (select 1 from quizzes q where q.id = questions.quiz_id and q.owner = auth.uid()::uuid)
  ) with check (
    exists (select 1 from quizzes q where q.id = questions.quiz_id and q.owner = auth.uid()::uuid)
  );

create policy "questions_delete_if_quiz_owner"
  on questions for delete to authenticated using (
    exists (select 1 from quizzes q where q.id = questions.quiz_id and q.owner = auth.uid()::uuid)
  );

/* Options: same pattern as questions */
alter table options enable row level security;

create policy "options_public_select"
  on options for select to authenticated using (
    exists (
      select 1 from questions qq
      join quizzes q on qq.quiz_id = q.id
      where qq.id = options.question_id and q.owner = auth.uid()::uuid
    )
  );

create policy "options_insert_if_quiz_owner"
  on options for insert to authenticated with check (
    exists (
      select 1 from questions qq
      join quizzes q on qq.quiz_id = q.id
      where qq.id = options.question_id and q.owner = auth.uid()::uuid
    )
  );

create policy "options_modify_if_quiz_owner"
  on options for update to authenticated using (
    exists (
      select 1 from questions qq
      join quizzes q on qq.quiz_id = q.id
      where qq.id = options.question_id and q.owner = auth.uid()::uuid
    )
  ) with check (
    exists (
      select 1 from questions qq
      join quizzes q on qq.quiz_id = q.id
      where qq.id = options.question_id and q.owner = auth.uid()::uuid
    )
  );

create policy "options_delete_if_quiz_owner"
  on options for delete to authenticated using (
    exists (
      select 1 from questions qq
      join quizzes q on qq.quiz_id = q.id
      where qq.id = options.question_id and q.owner = auth.uid()::uuid
    )
  );

-- Modify attempt table's user_id column to be uuid
alter table attempts
alter column user_id
type uuid
using (user_id::uuid);

/* Attempts: allow authenticated users to insert (user_id enforced), and allow selects for attempt owner or quiz owner */
alter table attempts enable row level security;

create policy "attempts_insert_authenticated"
  on attempts for insert to authenticated with check (user_id = auth.uid());

create policy "attempts_select_owner_or_quiz_owner"
  on attempts for select to authenticated using (
    user_id = auth.uid()
    or exists (select 1 from quizzes q where q.id = attempts.quiz_id and q.owner = auth.uid()::uuid)
  );

create policy "attempts_delete_quiz_owner"
  on attempts for delete to authenticated using (
    exists (select 1 from quizzes q where q.id = attempts.quiz_id and q.owner = auth.uid()::uuid)
  );
