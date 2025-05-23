document.addEventListener('DOMContentLoaded', function() {
    // Mobile navigation toggle
    const navToggle = document.getElementById('nav-toggle');
    const sidebar = document.getElementById('sidebar');
    
    // Desktop sidebar toggle
    const sidebarToggle = document.getElementById('sidebar-toggle');
    
    if (navToggle && sidebar) {
        navToggle.addEventListener('click', function() {
            sidebar.classList.toggle('open');
            navToggle.classList.toggle('active');
        });
    }
    
    // Desktop sidebar collapse/expand
    if (sidebarToggle && sidebar) {
        sidebarToggle.addEventListener('click', function() {
            sidebar.classList.toggle('collapsed');
            sidebarToggle.classList.toggle('collapsed');
            
            // Update arrow direction
            const arrow = sidebarToggle.querySelector('span');
            if (sidebar.classList.contains('collapsed')) {
                arrow.innerHTML = '›';
            } else {
                arrow.innerHTML = '‹';
            }
            
            // Store preference in localStorage if available
            try {
                localStorage.setItem('sidebar-collapsed', sidebar.classList.contains('collapsed'));
            } catch (e) {
                // localStorage not available, ignore
            }
        });
        
        // Restore sidebar state from localStorage if available
        try {
            const isCollapsed = localStorage.getItem('sidebar-collapsed') === 'true';
            if (isCollapsed) {
                sidebar.classList.add('collapsed');
                sidebarToggle.classList.add('collapsed');
                const arrow = sidebarToggle.querySelector('span');
                if (arrow) arrow.innerHTML = '›';
            }
        } catch (e) {
            // localStorage not available, ignore
        }
    }
    
    // Folder toggle functionality
    const folderToggles = document.querySelectorAll('.folder-toggle');
    
    folderToggles.forEach(toggle => {
        toggle.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('data-target');
            const targetFolder = document.getElementById(targetId);
            const toggleIcon = this.querySelector('.toggle-icon');
            
            if (targetFolder) {
                targetFolder.classList.toggle('expanded');
                this.setAttribute('aria-expanded', targetFolder.classList.contains('expanded'));
                
                if (targetFolder.classList.contains('expanded')) {
                    toggleIcon.textContent = '▼';
                } else {
                    toggleIcon.textContent = '▶';
                }
            }
        });
    });
    
    // Auto-expand folders containing current page
    const currentLink = document.querySelector('.nav-link.current');
    if (currentLink) {
        let parent = currentLink.closest('.nav-subtree');
        while (parent) {
            parent.classList.add('expanded');
            const parentToggle = document.querySelector(`[data-target="${parent.id}"]`);
            if (parentToggle) {
                const toggleIcon = parentToggle.querySelector('.toggle-icon');
                if (toggleIcon) {
                    toggleIcon.textContent = '▼';
                }
                parentToggle.setAttribute('aria-expanded', 'true');
            }
            parent = parent.parentElement.closest('.nav-subtree');
        }
    }
    
    // Close sidebar when clicking outside on mobile
    document.addEventListener('click', function(e) {
        if (window.innerWidth <= 768) {
            if (!sidebar.contains(e.target) && !navToggle.contains(e.target)) {
                sidebar.classList.remove('open');
                navToggle.classList.remove('active');
            }
        }
    });
    
    // Handle window resize
    window.addEventListener('resize', function() {
        if (window.innerWidth > 768) {
            sidebar.classList.remove('open');
            navToggle.classList.remove('active');
        }
    });
    
    // Smooth scrolling for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
});