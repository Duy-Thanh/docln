function removeNavbar() {
    var navbar = document.getElementById('navbar');
    if (navbar) {
      navbar.parentNode.removeChild(navbar);
    }
  }

  // Attempt to remove the navbar immediately
  removeNavbar();

  // Function to set up the MutationObserver
  function setupObserver() {
    if (document.body) {
      // Use MutationObserver to watch for future changes
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          removeNavbar(); // Check for navbar on each mutation
        });
      });

      observer.observe(document.body, { childList: true, subtree: true });

      // Set a repeated check every 500ms for 5 seconds
      let checkInterval = setInterval(() => {
        removeNavbar();
      }, 500);

      // Stop checking after 5 seconds
      setTimeout(() => {
        clearInterval(checkInterval);
        observer.disconnect(); // Stop observing
      }, 5000);
    } else {
      // Retry after a short delay if document.body is not available
      setTimeout(setupObserver, 1);
    }
  }

  // Start the observer setup
  setupObserver();