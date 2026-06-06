const Router = {
  currentPage: 'dashboard',
  pages: {},

  register(name, renderFn) {
    this.pages[name] = renderFn;
  },

  navigate(page) {
    this.currentPage = page;
    document.querySelectorAll('.page').forEach(p => p.classList.add('hidden'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));

    const el = document.getElementById('page-' + page);
    const nav = document.querySelector(`[data-page="${page}"]`);
    if (el) el.classList.remove('hidden');
    if (nav) nav.classList.add('active');

    if (this.pages[page]) this.pages[page]();
  },

  init() {
    this.navigate('dashboard');
  }
};
