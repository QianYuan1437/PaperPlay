const toggle = document.querySelector('#theme');
let preference;
try { preference = localStorage.getItem('paperplay-theme'); } catch (_) { /* Storage is optional. */ }
document.body.classList.toggle('dark', preference ? preference === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches);
toggle.addEventListener('click', () => {
  const dark = document.body.classList.toggle('dark');
  try { localStorage.setItem('paperplay-theme', dark ? 'dark' : 'light'); } catch (_) {}
});
// Static download links keep working when GitHub's public API is unavailable.
fetch('https://api.github.com/repos/QianYuan1437/PaperPlay/releases/latest')
  .then(response => { if (!response.ok) throw new Error('No release'); return response.json(); })
  .then(release => {
    document.querySelector('#version').textContent = `${release.tag_name} · Windows 10 / 11 · x64 · 安装版与便携版`;
  }).catch(() => {});
