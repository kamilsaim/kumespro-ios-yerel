-- Yerel iOS ve Android aynı sözleşmeyi kullanır.
-- Her çağrı PostgreSQL transaction'ıdır. Beklenen satır değişmişse tüm çağrı geri alınır.
begin;

create table if not exists public.kp_islem_sonuclari (
  user_id uuid not null references auth.users(id) on delete cascade,
  istek_id uuid not null,
  istek jsonb not null,
  sonuc jsonb not null,
  created_at timestamptz not null default now(),
  primary key (user_id, istek_id)
);
alter table public.kp_islem_sonuclari enable row level security;
drop policy if exists kp_islem_kendi on public.kp_islem_sonuclari;
create policy kp_islem_kendi on public.kp_islem_sonuclari
  for all to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
revoke all on public.kp_islem_sonuclari from anon, authenticated;
grant select, insert on public.kp_islem_sonuclari to authenticated;

create or replace function public.kp_atomik_islem(istek_id uuid, islemler jsonb, kullanici_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  op jsonb;
  tablo text;
  tur text;
  kimlik text;
  mevcut jsonb;
  deger jsonb;
  beklenen jsonb;
  kolonlar text;
  alan text;
  izinli text[];
  eski public.kp_islem_sonuclari%rowtype;
  sonuc jsonb := '{"ok":true}'::jsonb;
begin
  if uid is null or kullanici_id is distinct from uid then raise exception 'Oturum değişti. Yeniden giriş yapın.'; end if;
  if istek_id is null or islemler is null or jsonb_typeof(islemler) <> 'array'
     or jsonb_array_length(islemler) = 0 or jsonb_array_length(islemler) > 20000 then
    raise exception 'Geçersiz işlem';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));
  select * into eski from public.kp_islem_sonuclari r
    where r.user_id = uid and r.istek_id = kp_atomik_islem.istek_id;
  if found then
    if eski.istek <> islemler then raise exception 'İstek kimliği farklı içerikle kullanıldı'; end if;
    return eski.sonuc;
  end if;
  for op in select value from jsonb_array_elements(islemler) loop
    tablo := op->>'tablo';
    tur := op->>'tur';
    kimlik := op->>'id';
    izinli := case tablo
      when 'kumesler' then array['ad','tur','irklar','not_','hareketler']
      when 'civciv_uniteleri' then array['ad','adet','hareketler']
      when 'kuluckalar' then array['ad','baslangic','sure','toplam_yumurta','kaynaklar','durum','cikim','not_']
      when 'satislar' then array['musteri','tarih','urunler','toplam','odenen','not_']
      when 'giderler' then array['tur','aciklama','tutar','tarih','kumes_id','odenen']
      when 'sezonlar' then array['ad','tarih','veri']
      else null end;
    if izinli is null or kimlik is null or kimlik = '' or tur is null or tur not in ('ekle','guncelle','sil') then
      raise exception 'İzin verilmeyen işlem';
    end if;
    deger := coalesce(op->'veri', '{}'::jsonb);
    if jsonb_typeof(deger) <> 'object' then raise exception 'Geçersiz kayıt'; end if;
    for alan in select jsonb_object_keys(deger) loop
      if not (alan = any(izinli)) then raise exception 'İzin verilmeyen alan'; end if;
    end loop;
    if tur <> 'ekle' then
      execute format('select to_jsonb(t) from public.%I t where id::text = $1 and user_id = $2 for update', tablo)
        into mevcut using kimlik, uid;
      beklenen := op->'beklenen';
      if mevcut is null or beklenen is null or jsonb_typeof(beklenen) <> 'object'
         or beklenen = '{}'::jsonb or not (mevcut @> beklenen) then
        raise exception 'Kayıt başka cihazda değişti. Verileri yenileyip tekrar deneyin.' using errcode = '40001';
      end if;
    end if;
    if tur = 'sil' then
      execute format('delete from public.%I where id::text = $1 and user_id = $2', tablo) using kimlik, uid;
    elsif tur = 'ekle' then
      deger := deger || jsonb_build_object('id', kimlik, 'user_id', uid);
      select string_agg(format('%I', key), ',') into kolonlar from jsonb_object_keys(deger) key;
      execute format('insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I, $1)',
        tablo, kolonlar, kolonlar, tablo) using deger;
    else
      if deger = '{}'::jsonb then raise exception 'Boş güncelleme'; end if;
      select string_agg(format('%I', key), ',') into kolonlar from jsonb_object_keys(deger) key;
      execute format('update public.%I set (%s) = (select %s from jsonb_populate_record(null::public.%I, $1)) where id::text = $2 and user_id = $3',
        tablo, kolonlar, kolonlar, tablo) using deger, kimlik, uid;
    end if;
  end loop;
  insert into public.kp_islem_sonuclari(user_id, istek_id, istek, sonuc)
    values(uid, istek_id, islemler, sonuc);
  return sonuc;
end;
$$;
revoke all on function public.kp_atomik_islem(uuid, jsonb, uuid) from public, anon;
grant execute on function public.kp_atomik_islem(uuid, jsonb, uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
