-- quizzes table
create table if not exists quizzes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  config jsonb,
  created_at timestamptz default now()
);

-- questions table
create table if not exists questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid references quizzes(id) on delete cascade,
  text text,
  answer_type text,
  answer_text text,
  answer_number numeric,
  created_at timestamptz default now()
);

-- options table
create table if not exists options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid references questions(id) on delete cascade,
  label text,
  value text,
  is_correct boolean default false
);

-- attempts table
create table if not exists attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid references quizzes(id) on delete cascade,
  user_id text,
  score numeric,
  details jsonb,
  created_at timestamptz default now()
);
