using Godot;
using System;

namespace Util {
    [GlobalClass]
    public partial class TimerResource : Resource
    {
        [Export] public float Duration { get; set; } = 1.0f;
        [Export] public bool OneShot { get; set; } = true;

        public float TimeLeft { get; private set; } = 0.0f;
        public bool IsActive { get; private set; } = false;

        public event Action OnTimeout;

        public void Start(float customDuration = -1.0f)
        {
            TimeLeft = customDuration > 0 ? customDuration : Duration;
            IsActive = true;
        }

        public void Update(float delta)
        {
            if (!IsActive) return;

            TimeLeft -= delta;
            if (TimeLeft <= 0)
            {
                IsActive = false;
                TimeLeft = 0;
                OnTimeout?.Invoke();
            }
        }
    }
}