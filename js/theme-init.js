// Apply the saved theme before first paint. localStorage holds only this UI preference.
try {
  const t = localStorage.getItem('fn-theme');
  if (t === 'light' || t === 'dark') document.documentElement.dataset.theme = t;
} catch { /* storage unavailable: follow the system theme */ }
