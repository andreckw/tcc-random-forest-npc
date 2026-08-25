using Godot;

namespace Util
{
    public static class WorldClock
    {
        public const float HoursPerDay = 24f;

        public static float HoursPerRealSecond { get; set; } = 0.5f;

        public static float TotalHours => (float)(Time.GetTicksMsec() / 1000.0) * HoursPerRealSecond;

        public static float Hour => TotalHours % HoursPerDay;

        public static float NormalizedHour => Hour / HoursPerDay;
    }
}
