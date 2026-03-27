/* banner-inject.js - role-based banner and modal injection
   Usage: include this script in your site layout and ensure window.TFX.currentUser.role is set.
*/
(function () {
  try {
    const role = (window.TFX && window.TFX.currentUser && window.TFX.currentUser.role) || 'guest';
    const roleMap = {
      'contractor': 'tfx-banner-contractor',
      'institution': 'tfx-banner-contractor',
      'customer': 'tfx-banner-customer',
      'member': 'tfx-banner-customer',
      'admin': 'tfx-banner-admin',
      'sysadmin': 'tfx-banner-admin',
      'developer': 'tfx-banner-dev',
      'owner': 'tfx-banner-owner'
    };
    const bannerId = roleMap[role];
    if (bannerId) {
      const banner = document.getElementById(bannerId);
      if (banner) {
        banner.style.display = 'block';
        document.body.insertAdjacentElement('afterbegin', banner);
      }
    }
    // Modal trigger example: show admin modal if role is admin and a query param ?showAdminModal=1
    const urlParams = new URLSearchParams(window.location.search);
    if (role === 'admin' && urlParams.get('showAdminModal') === '1') {
      const tpl = document.getElementById('tfx-modal-admin');
      if (tpl) {
        const node = tpl.content.cloneNode(true);
        document.body.appendChild(node);
      }
    }
  } catch (e) {
    console.error('TFX banner injection error', e);
  }
})();
