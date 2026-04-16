import { createClient } from "@/utils/supabase/server";
import { cookies } from "next/headers";

type BookingRow = {
  id: string;
  date: string;
  time: string;
  status: string;
};

export default async function Page() {
  const cookieStore = await cookies();
  const supabase = createClient(cookieStore);

  const { data: bookings, error } = await supabase
    .from("bookings")
    .select("id,date,time,status")
    .order("created_at", { ascending: false })
    .limit(50);

  if (error) {
    return (
      <main style={{ padding: 24, fontFamily: "system-ui" }}>
        <h1>Bookings</h1>
        <p>Could not load bookings (sign in may be required): {error.message}</p>
      </main>
    );
  }

  const rows = (bookings ?? []) as BookingRow[];

  return (
    <main style={{ padding: 24, fontFamily: "system-ui" }}>
      <h1>Bookings</h1>
      {rows.length === 0 ? (
        <p>No rows yet. Use the Flutter app to create bookings.</p>
      ) : (
        <ul>
          {rows.map((b) => (
            <li key={b.id}>
              {b.date} {b.time} — {b.status}
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
