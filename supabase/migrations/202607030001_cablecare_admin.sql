create extension if not exists "uuid-ossp";

create type customer_status as enum ('active', 'inactive', 'suspended', 'disconnected');
create type connection_type as enum ('prepaid', 'postpaid');
create type stb_status as enum ('available', 'assigned', 'repair', 'damaged');
create type bill_status as enum ('paid', 'pending', 'partial', 'cancelled');
create type payment_method as enum ('cash', 'upi', 'bank_transfer', 'cheque');
create type complaint_type as enum ('no_signal', 'wire_cut', 'remote_issue', 'box_issue', 'low_quality', 'subscription', 'other');
create type complaint_priority as enum ('low', 'medium', 'high', 'urgent');
create type complaint_status as enum ('open', 'assigned', 'in_progress', 'completed', 'closed');
create type expense_category as enum ('electricity', 'fuel', 'salary', 'equipment', 'cable_purchase', 'maintenance', 'office_rent', 'miscellaneous');
create type notification_channel as enum ('sms', 'whatsapp', 'email', 'in_app');
create type notification_status as enum ('queued', 'sent', 'failed', 'read');

create sequence customer_code_seq start 1001;
create sequence receipt_number_seq start 10001;
create sequence complaint_number_seq start 5001;

create table admins (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null unique,
  avatar_url text,
  created_at timestamptz not null default now()
);

create or replace function is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists(select 1 from admins where admins.id = auth.uid())
$$;

create table technicians (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  phone text not null unique,
  jobs_count int not null default 0,
  completed_count int not null default 0,
  pending_count int not null default 0,
  created_at timestamptz not null default now()
);

create table areas (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  code text not null unique,
  assigned_technician_id uuid references technicians(id) on delete set null,
  customer_count int not null default 0,
  pending_amount numeric(12,2) not null default 0,
  monthly_collection numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create table technician_areas (
  technician_id uuid references technicians(id) on delete cascade,
  area_id uuid references areas(id) on delete cascade,
  primary key (technician_id, area_id)
);

create table set_top_boxes (
  id uuid primary key default uuid_generate_v4(),
  box_id text not null unique,
  vc_number text not null unique,
  smart_card_number text unique,
  brand text,
  model text,
  serial_number text unique,
  purchase_date date,
  status stb_status not null default 'available',
  created_at timestamptz not null default now()
);

create table customers (
  id uuid primary key default uuid_generate_v4(),
  customer_code text not null unique default ('CC-' || nextval('customer_code_seq')),
  name text not null,
  phone text not null,
  alternate_number text,
  email text,
  address text,
  village text,
  area_id uuid references areas(id) on delete set null,
  pincode text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  photo_url text,
  id_proof_url text,
  box_id text,
  vc_number text,
  smart_card_number text,
  connection_type connection_type not null default 'postpaid',
  monthly_charge numeric(12,2) not null default 0,
  installation_charge numeric(12,2) not null default 0,
  security_deposit numeric(12,2) not null default 0,
  installation_date date,
  status customer_status not null default 'active',
  notes text,
  created_at timestamptz not null default now()
);

create table customer_box_mapping (
  id uuid primary key default uuid_generate_v4(),
  customer_id uuid not null references customers(id) on delete cascade,
  stb_id uuid not null references set_top_boxes(id) on delete restrict,
  assigned_at timestamptz not null default now(),
  returned_at timestamptz,
  unique (stb_id, returned_at)
);

create table monthly_bills (
  id uuid primary key default uuid_generate_v4(),
  customer_id uuid not null references customers(id) on delete cascade,
  bill_month int not null check (bill_month between 1 and 12),
  bill_year int not null,
  amount numeric(12,2) not null,
  previous_due numeric(12,2) not null default 0,
  discount numeric(12,2) not null default 0,
  fine numeric(12,2) not null default 0,
  total_amount numeric(12,2) generated always as (amount + previous_due + fine - discount) stored,
  status bill_status not null default 'pending',
  created_at timestamptz not null default now(),
  unique (customer_id, bill_month, bill_year)
);

create table payments (
  id uuid primary key default uuid_generate_v4(),
  receipt_number text not null unique default ('RCPT-' || nextval('receipt_number_seq')),
  customer_id uuid references customers(id) on delete set null,
  bill_id uuid references monthly_bills(id) on delete set null,
  amount numeric(12,2) not null,
  discount numeric(12,2) not null default 0,
  fine numeric(12,2) not null default 0,
  payment_method payment_method not null default 'cash',
  notes text,
  created_at timestamptz not null default now()
);

create table payment_history (
  id uuid primary key default uuid_generate_v4(),
  customer_id uuid references customers(id) on delete set null,
  amount numeric(12,2) not null,
  payment_method payment_method not null default 'cash',
  notes text,
  created_at timestamptz not null default now()
);

create table complaints (
  id uuid primary key default uuid_generate_v4(),
  complaint_number text not null unique default ('CMP-' || nextval('complaint_number_seq')),
  customer_id uuid references customers(id) on delete set null,
  phone text,
  area_id uuid references areas(id) on delete set null,
  complaint_type complaint_type not null default 'other',
  description text not null,
  priority complaint_priority not null default 'medium',
  assigned_technician_id uuid references technicians(id) on delete set null,
  status complaint_status not null default 'open',
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table complaint_updates (
  id uuid primary key default uuid_generate_v4(),
  complaint_id uuid not null references complaints(id) on delete cascade,
  status complaint_status not null,
  note text,
  created_by uuid references admins(id) on delete set null,
  created_at timestamptz not null default now()
);

create table expenses (
  id uuid primary key default uuid_generate_v4(),
  expense_date date not null default current_date,
  category expense_category not null,
  amount numeric(12,2) not null,
  paid_to text,
  payment_method payment_method not null default 'cash',
  notes text,
  created_at timestamptz not null default now()
);

create table notifications (
  id uuid primary key default uuid_generate_v4(),
  recipient_phone text not null,
  channel notification_channel not null,
  message text not null,
  status notification_status not null default 'queued',
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create table settings (
  id uuid primary key default uuid_generate_v4(),
  company_name text,
  logo_url text,
  address text,
  gst_number text,
  default_monthly_charge numeric(12,2) default 0,
  late_fine numeric(12,2) default 0,
  currency text default 'INR',
  receipt_footer text,
  created_at timestamptz not null default now()
);

create table audit_logs (
  id uuid primary key default uuid_generate_v4(),
  actor_id uuid references admins(id) on delete set null,
  action text not null,
  table_name text,
  row_id uuid,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index customers_search_idx on customers using gin (to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(phone,'') || ' ' || coalesce(customer_code,'')));
create index customers_area_status_idx on customers(area_id, status);
create index bills_status_idx on monthly_bills(status, bill_year, bill_month);
create index payments_created_idx on payments(created_at);
create index complaints_status_idx on complaints(status, priority);
create index expenses_date_idx on expenses(expense_date);

alter table admins enable row level security;
alter table areas enable row level security;
alter table technicians enable row level security;
alter table technician_areas enable row level security;
alter table set_top_boxes enable row level security;
alter table customers enable row level security;
alter table customer_box_mapping enable row level security;
alter table monthly_bills enable row level security;
alter table payments enable row level security;
alter table payment_history enable row level security;
alter table complaints enable row level security;
alter table complaint_updates enable row level security;
alter table expenses enable row level security;
alter table notifications enable row level security;
alter table settings enable row level security;
alter table audit_logs enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array[
    'admins','areas','technicians','technician_areas','set_top_boxes','customers',
    'customer_box_mapping','monthly_bills','payments','payment_history','complaints',
    'complaint_updates','expenses','notifications','settings','audit_logs'
  ]
  loop
    execute format('create policy "%I admin select" on %I for select using (is_admin())', t, t);
    execute format('create policy "%I admin insert" on %I for insert with check (is_admin())', t, t);
    execute format('create policy "%I admin update" on %I for update using (is_admin()) with check (is_admin())', t, t);
    execute format('create policy "%I admin delete" on %I for delete using (is_admin())', t, t);
  end loop;
end $$;
