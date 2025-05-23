// Complete slideshow functionality with custom scaling

window.toggleViewMode = function () {
  const doc = document.querySelector('.main-content');
  const slides = document.getElementById('slideshow-view');

  if (slides.style.display === 'none') {
    // Switch to slideshow mode
    doc.style.display = 'none';
    slides.style.display = 'block';
    
    // Collapse sidebar and store previous state
    collapseSidebarForSlideshow();
    
    buildSlides();
    
    setTimeout(() => {
      Reveal.initialize({
        controls: true,
        progress: true,
        hash: false,
        transition: 'slide',
        embedded: true,
        
        // Simple fixed dimensions - we'll handle scaling ourselves
        width: 1200,
        height: 800,
        
        // Disable Reveal's scaling since we're doing it ourselves
        minScale: 1,
        maxScale: 1,
        margin: 0.1,
        center: true,
        
        keyboard: {
          27: function() { // ESC key
            exitSlideshow();
          },
          37: 'left', 39: 'right', 38: 'up', 40: 'down',
          32: 'next', 33: 'prev', 34: 'next', 35: 'last', 36: 'first'
        }
      });
      
      // Re-scale when slides change
      Reveal.addEventListener('slidechanged', function(event) {
        setTimeout(() => scaleSlides(), 50);
      });
      
      Reveal.sync();
    }, 50);
  } else {
    // Switch back to document mode
    exitSlideshow();
  }
}

function exitSlideshow() {
  const doc = document.querySelector('.main-content');
  const slides = document.getElementById('slideshow-view');
  
  // With embedded mode, we don't need to destroy or clean up styles
  // Just toggle the visibility
  doc.style.display = 'block';
  slides.style.display = 'none';
  
  // Restore sidebar state
  restoreSidebarFromSlideshow();
}

// Store sidebar state before slideshow and collapse it
function collapseSidebarForSlideshow() {
  const sidebar = document.getElementById('sidebar');
  const sidebarToggle = document.getElementById('sidebar-toggle');
  
  if (sidebar && sidebarToggle) {
    // Store current collapsed state
    const wasCollapsed = sidebar.classList.contains('collapsed');
    
    // Store in a temporary property for restoration
    window.sidebarStateBeforeSlideshow = wasCollapsed;
    
    // Collapse sidebar if not already collapsed
    if (!wasCollapsed) {
      sidebar.classList.add('collapsed');
      sidebarToggle.classList.add('collapsed');
      
      const arrow = sidebarToggle.querySelector('span');
      if (arrow) arrow.innerHTML = '›';
    }
  }
}

// Restore sidebar state after slideshow
function restoreSidebarFromSlideshow() {
  const sidebar = document.getElementById('sidebar');
  const sidebarToggle = document.getElementById('sidebar-toggle');
  
  if (sidebar && sidebarToggle && typeof window.sidebarStateBeforeSlideshow !== 'undefined') {
    // Restore to previous state
    if (!window.sidebarStateBeforeSlideshow) {
      // Was expanded before slideshow, so expand it again
      sidebar.classList.remove('collapsed');
      sidebarToggle.classList.remove('collapsed');
      
      const arrow = sidebarToggle.querySelector('span');
      if (arrow) arrow.innerHTML = '‹';
    }
    
    // Clean up temporary storage
    delete window.sidebarStateBeforeSlideshow;
  }
}

function buildSlides() {
  // Get the main content and create a clean copy
  const contentElement = document.querySelector('.content');
  const contentCopy = contentElement.cloneNode(true);
  
  // Remove all no-print elements
  contentCopy.querySelectorAll('.no-print').forEach(el => el.remove());
  
  // Remove page header (H1) elements
  contentCopy.querySelectorAll('h1').forEach(el => el.remove());
  
  // Remove any remaining export buttons or navigation elements
  contentCopy.querySelectorAll('.export-options, .export-buttons, .export-btn').forEach(el => el.remove());
  
  // Get the cleaned content
  const cleanContent = contentCopy.innerHTML;
  
  // Split content by H2 headers
  const h2Regex = /<h2[^>]*>.*?<\/h2>/gi;
  const h2Headers = cleanContent.match(h2Regex) || [];
  const contentSections = cleanContent.split(h2Regex);
  
  // Clear the slide container
  const slideContainer = document.getElementById('slides-container');
  slideContainer.innerHTML = '';
  
  // Create slides - skip the first section if it's before any H2
  for (let i = 0; i < h2Headers.length; i++) {
    const slide = document.createElement('section');
    
    // Combine H2 header with its following content
    const slideContent = h2Headers[i] + (contentSections[i + 1] || '');
    slide.innerHTML = slideContent.trim();
    
    slideContainer.appendChild(slide);
  }
  
  // If there's content before the first H2, create an intro slide
  if (contentSections[0] && contentSections[0].trim()) {
    const introSlide = document.createElement('section');
    introSlide.innerHTML = contentSections[0].trim();
    slideContainer.insertBefore(introSlide, slideContainer.firstChild);
  }
  
  // Apply custom scaling after slides are created
  setTimeout(() => {
    scaleSlides();
  }, 100);
}

function scaleSlides() {
  const slides = document.querySelectorAll('#slides-container section');
  const slideshow = document.getElementById('slideshow-view');
  
  // Get available space (accounting for controls and margins)
  const availableWidth = slideshow.clientWidth - 100;
  const availableHeight = slideshow.clientHeight - 100;
  
  slides.forEach(slide => {
    // Reset transform completely before measuring
    slide.style.transform = 'none';
    slide.style.width = 'auto';
    slide.style.height = 'auto';
    slide.style.transformOrigin = 'top center';
    
    // Force a reflow
    slide.offsetHeight;
    
    // Measure the natural content size
    const contentWidth = slide.scrollWidth;
    const contentHeight = slide.scrollHeight;
    
    // Calculate scale factors
    const scaleX = availableWidth / contentWidth;
    const scaleY = availableHeight / contentHeight;
    
    // Use the smaller scale to ensure everything fits
    const scale = Math.min(scaleX, scaleY);
    
    // Apply scaling - remove the translation, just scale
    slide.style.transform = `scale(${scale})`;
    
    // Adjust container size to prevent overflow
    slide.style.width = `${contentWidth}px`;
    slide.style.height = `${contentHeight}px`;
    
    console.log(`Slide: content=${contentWidth}x${contentHeight}, available=${availableWidth}x${availableHeight}, scale=${scale}`);
  });
}