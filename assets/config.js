/* =====================================================================
   CẤU HÌNH — điền 2 giá trị từ Supabase (Project Settings → API):
   ===================================================================== */
window.APP_CONFIG = {
  SUPABASE_URL: "",       // ví dụ: https://abcdxyz.supabase.co
  SUPABASE_ANON_KEY: "",  // "anon public" key (KHÔNG dùng service_role key)

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
