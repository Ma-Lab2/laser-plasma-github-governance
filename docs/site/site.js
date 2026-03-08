document.querySelectorAll('.copy-button').forEach((button) => {
  button.addEventListener('click', async () => {
    const target = document.getElementById(button.dataset.copyTarget);
    if (!target) return;
    const text = target.innerText;
    const original = button.textContent;
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = '已复制';
    } catch (err) {
      button.textContent = '复制失败';
    }
    window.setTimeout(() => {
      button.textContent = original;
    }, 1400);
  });
});

document.querySelectorAll('.faq-item').forEach((item) => {
  const trigger = item.querySelector('.faq-trigger');
  const icon = item.querySelector('.faq-icon');
  if (!trigger || !icon) return;
  const sync = () => {
    icon.textContent = item.classList.contains('open') ? '−' : '+';
  };
  trigger.addEventListener('click', () => {
    item.classList.toggle('open');
    sync();
  });
  sync();
});

const currentPage = document.body.dataset.page;
document.querySelectorAll('[data-page-link]').forEach((link) => {
  if (link.dataset.pageLink === currentPage) {
    link.classList.add('active');
  }
});
