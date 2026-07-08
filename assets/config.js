/* =====================================================================
   CẤU HÌNH — điền 2 giá trị từ Supabase (Project Settings → API):
   ===================================================================== */
window.APP_CONFIG = {
  SUPABASE_URL: "https://ltfccbvbjbewvragftcy.supabase.co",       // ví dụ: https://abcdxyz.supabase.co
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0ZmNjYnZiamJld3ZyYWdmdGN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0ODU0MDAsImV4cCI6MjA5OTA2MTQwMH0.V7NbxYq07znKZvQl3wzCge8QLrbqRLf46viw518FL7M",  // "anon public" key (KHÔNG dùng service_role key)

  REFRESH_SECONDS: 15,    // chu kỳ polling dự phòng cho leaderboard
};

/* Tạo client dùng chung cho cả 3 trang (index / board / admin).
   Trả về null nếu chưa cấu hình → trang sẽ hiện màn hình hướng dẫn. */
window.getSupabase = function () {
  const c = window.APP_CONFIG;
  if (!c.SUPABASE_URL || !c.SUPABASE_ANON_KEY) return null;
  if (!window.__sb) {
    window.__sb = window.supabase.createClient(c.SUPABASE_URL, c.SUPABASE_ANON_KEY, {
      auth: { persistSession: false },
    });
  }
  return window.__sb;
};
