document.addEventListener('DOMContentLoaded', function() {
    
    // Log specific accion-collateral elements for debugging
    const accionFolder = document.querySelector('[data-path="accion-collateral"]');
    if (accionFolder) {
        const nameLink = accionFolder.querySelector('.folder-name-link');
        const toggle = accionFolder.querySelector('.folder-toggle, .folder-toggle-only');
        console.log('Navigation Debug: accion-collateral folder found', {
            folder: accionFolder,
            nameLink: nameLink,
            toggle: toggle
        });
    } else {
        console.log('Navigation Debug: accion-collateral folder NOT found');
    }
    
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
    
    // Hierarchical folder toggle functionality
    const folderToggles = document.querySelectorAll('.folder-toggle, .folder-toggle-only');
    
    folderToggles.forEach(toggle => {
        toggle.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            
            const targetId = this.getAttribute('data-target');
            const targetFolder = document.getElementById(targetId);
            const toggleIcon = this.querySelector('.toggle-icon');
            
            console.log('Toggle clicked:', targetId, targetFolder); // Debug log
            
            if (targetFolder) {
                // Force reflow to ensure CSS is applied
                targetFolder.offsetHeight;
                
                // Check actual visual state, not just the class
                const computedMaxHeight = window.getComputedStyle(targetFolder).maxHeight;
                const isVisuallyExpanded = computedMaxHeight !== '0px';
                
                // Debug current state
                console.log('Current state - visually expanded:', isVisuallyExpanded, 'has expanded class:', targetFolder.classList.contains('expanded'));
                console.log('Computed max-height:', computedMaxHeight);
                
                if (isVisuallyExpanded) {
                    targetFolder.classList.remove('expanded');
                    this.setAttribute('aria-expanded', 'false');
                    if (toggleIcon) toggleIcon.textContent = '▶';
                } else {
                    targetFolder.classList.add('expanded');
                    this.setAttribute('aria-expanded', 'true');
                    if (toggleIcon) toggleIcon.textContent = '▼';
                }
                
                // Force another reflow
                targetFolder.offsetHeight;
                
                // Debug new state
                const newComputedMaxHeight = window.getComputedStyle(targetFolder).maxHeight;
                console.log('New state - expanded:', !isVisuallyExpanded, 'classes:', targetFolder.className);
                console.log('New computed max-height:', newComputedMaxHeight);
                
                // Save folder state in localStorage
                saveFolderState(targetId, !isVisuallyExpanded);
                
                // Save scroll position after toggle (with longer delay for CSS transition)
                setTimeout(saveNavigationScrollPosition, 350);
            }
        });
        
        // Add keyboard support
        toggle.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                this.click();
            }
        });
    });
    
    // Make folder name links also toggle the folder instead of navigating
    const folderNameLinks = document.querySelectorAll('.folder-name-link');
    
    folderNameLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            
            // Find the corresponding toggle button
            const folderHeader = this.closest('.nav-folder-header');
            const toggleButton = folderHeader ? folderHeader.querySelector('.folder-toggle, .folder-toggle-only') : null;
            
            if (toggleButton) {
                // Trigger the toggle functionality
                toggleButton.click();
                
                // Optional: Add visual feedback that we're toggling
                this.style.backgroundColor = 'rgba(25, 118, 210, 0.1)';
                setTimeout(() => {
                    this.style.backgroundColor = '';
                }, 150);
            }
        });
        
        // Add keyboard support for folder name links
        link.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                this.click();
            }
        });
        
        // Add a small indicator to show that folder names are clickable for toggling
        const originalHref = link.getAttribute('href');
        if (originalHref) {
            // Store the original href for potential future use
            link.setAttribute('data-index-url', originalHref);
            
            // Remove the href to prevent navigation
            link.removeAttribute('href');
            
            // Add visual indicator that this toggles the folder
            link.style.cursor = 'pointer';
            
            // Optionally add a small icon or modify the title to indicate it's for toggling
            const folderIcon = link.querySelector('.folder-icon');
            if (folderIcon) {
                folderIcon.title = 'Click to expand/collapse folder';
            }
        }
    });
    
    // Auto-expand folders containing current page and restore saved states
    initializeFolderStates();
    
    // Restore navigation scroll position
    restoreNavigationScrollPosition();
    
    // Save navigation scroll position before page unload and when clicking navigation links
    setupScrollPositionSaving();
    
    // Close sidebar when clicking outside on mobile
    document.addEventListener('click', function(e) {
        if (window.innerWidth <= 768) {
            if (sidebar && navToggle && !sidebar.contains(e.target) && !navToggle.contains(e.target)) {
                sidebar.classList.remove('open');
                navToggle.classList.remove('active');
            }
        }
    });
    
    // Handle window resize
    window.addEventListener('resize', function() {
        if (window.innerWidth > 768) {
            if (sidebar && navToggle) {
                sidebar.classList.remove('open');
                navToggle.classList.remove('active');
            }
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
    
    // Make utility functions available globally for debugging/console use
    window.navUtils = {
        expandAllFolders,
        collapseAllFolders,
        clearFolderStates,
        initializeFolderStates,
        saveNavigationScrollPosition,
        restoreNavigationScrollPosition,
        debugFolders: () => {
            console.log('=== Navigation Debug ===');
            const allFolders = document.querySelectorAll('.nav-subtree');
            allFolders.forEach((folder, index) => {
                const computed = window.getComputedStyle(folder);
                console.log(`Folder ${index} (${folder.id}):`, {
                    classes: folder.className,
                    display: computed.display,
                    maxHeight: computed.maxHeight,
                    overflow: computed.overflow,
                    hasExpanded: folder.classList.contains('expanded')
                });
            });
        }
    };
});

// Initialize folder states - restore from localStorage and auto-expand current path
function initializeFolderStates() {
    // First, ensure all folders start collapsed unless they should be expanded
    const allFolders = document.querySelectorAll('.nav-subtree');
    allFolders.forEach(folder => {
        folder.classList.remove('expanded');
    });
    
    // Reset all toggle icons to collapsed state
    const allToggles = document.querySelectorAll('.folder-toggle, .folder-toggle-only');
    allToggles.forEach(toggle => {
        toggle.setAttribute('aria-expanded', 'false');
        const toggleIcon = toggle.querySelector('.toggle-icon');
        if (toggleIcon) {
            toggleIcon.textContent = '▶';
        }
    });
    
    // Small delay to ensure DOM updates are applied
    setTimeout(() => {
        const currentLink = document.querySelector('.nav-link.current');
        const expandedFolders = new Set();
        
        // Get saved folder states from localStorage
        try {
            const savedStates = localStorage.getItem('nav-folder-states');
            if (savedStates) {
                const states = JSON.parse(savedStates);
                Object.keys(states).forEach(folderId => {
                    if (states[folderId]) {
                        expandedFolders.add(folderId);
                    }
                });
            }
        } catch (e) {
            // localStorage not available or invalid data, ignore
        }
        
        // Auto-expand folders containing current page (overrides saved state)
        if (currentLink) {
            let parent = currentLink.closest('.nav-subtree');
            while (parent) {
                expandedFolders.add(parent.id);
                const parentFolder = parent.closest('.nav-folder');
                if (parentFolder) {
                    const grandParent = parentFolder.parentElement;
                    if (grandParent && grandParent.classList.contains('nav-subtree')) {
                        parent = grandParent;
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            }
        }
        
        // Apply all expanded states
        expandedFolders.forEach(folderId => {
            const folder = document.getElementById(folderId);
            const toggle = document.querySelector(`[data-target="${folderId}"]`);
            
            if (folder && toggle) {
                folder.classList.add('expanded');
                toggle.setAttribute('aria-expanded', 'true');
                
                const toggleIcon = toggle.querySelector('.toggle-icon');
                if (toggleIcon) {
                    toggleIcon.textContent = '▼';
                }
            }
        });
        
        console.log('Folder states initialized. Expanded folders:', Array.from(expandedFolders));
    }, 50); // Small delay to ensure initial collapse is applied
}

// Save individual folder state to localStorage
function saveFolderState(folderId, isExpanded) {
    try {
        let savedStates = {};
        const existing = localStorage.getItem('nav-folder-states');
        if (existing) {
            savedStates = JSON.parse(existing);
        }
        
        savedStates[folderId] = isExpanded;
        localStorage.setItem('nav-folder-states', JSON.stringify(savedStates));
    } catch (e) {
        // localStorage not available, ignore
    }
}

// Save navigation scroll position to localStorage
function saveNavigationScrollPosition() {
    try {
        const navTree = document.querySelector('.nav-tree');
        const sidebar = document.getElementById('sidebar');
        
        if (navTree) {
            const scrollTop = navTree.scrollTop || (sidebar ? sidebar.scrollTop : 0);
            localStorage.setItem('nav-scroll-position', scrollTop.toString());
        }
    } catch (e) {
        // localStorage not available, ignore
    }
}

// Restore navigation scroll position from localStorage
function restoreNavigationScrollPosition() {
    try {
        const savedScrollPosition = localStorage.getItem('nav-scroll-position');
        if (savedScrollPosition !== null) {
            const scrollTop = parseInt(savedScrollPosition, 10);
            
            // Try multiple possible scroll containers
            const navTree = document.querySelector('.nav-tree');
            const sidebar = document.getElementById('sidebar');
            const navContainer = document.querySelector('.nav-container');
            
            // Use requestAnimationFrame to ensure DOM is ready
            requestAnimationFrame(() => {
                // Try different scroll containers in order of preference
                if (navTree && navTree.scrollHeight > navTree.clientHeight) {
                    navTree.scrollTop = scrollTop;
                } else if (sidebar && sidebar.scrollHeight > sidebar.clientHeight) {
                    sidebar.scrollTop = scrollTop;
                } else if (navContainer && navContainer.scrollHeight > navContainer.clientHeight) {
                    navContainer.scrollTop = scrollTop;
                }
            });
        }
    } catch (e) {
        // localStorage not available, ignore
    }
}

// Setup scroll position saving for navigation links and page unload
function setupScrollPositionSaving() {
    // Save scroll position when clicking any actual navigation link (not folder names that toggle)
    const navLinks = document.querySelectorAll('.nav-link');
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            // Only save scroll position if this is actually a navigation link with href
            if (this.href && !this.classList.contains('folder-toggle') && !this.classList.contains('folder-toggle-only') && !this.classList.contains('folder-name-link')) {
                saveNavigationScrollPosition();
            }
        });
    });
    
    // Save scroll position periodically while scrolling
    let scrollTimeout;
    const scrollableElements = [
        document.querySelector('.nav-tree'),
        document.getElementById('sidebar'),
        document.querySelector('.nav-container')
    ].filter(Boolean); // Remove null elements
    
    scrollableElements.forEach(element => {
        element.addEventListener('scroll', function() {
            clearTimeout(scrollTimeout);
            scrollTimeout = setTimeout(() => {
                saveNavigationScrollPosition();
            }, 150); // Debounce scroll saving
        });
    });
    
    // Save scroll position before page unload
    window.addEventListener('beforeunload', saveNavigationScrollPosition);
    
    // Also save when visibility changes (e.g., switching tabs)
    document.addEventListener('visibilitychange', function() {
        if (document.visibilityState === 'hidden') {
            saveNavigationScrollPosition();
        }
    });
}

// Clear all saved folder states (utility function)
function clearFolderStates() {
    try {
        localStorage.removeItem('nav-folder-states');
        localStorage.removeItem('nav-scroll-position');
    } catch (e) {
        // localStorage not available, ignore
    }
}

// Expand all folders (utility function)
function expandAllFolders() {
    const allFolders = document.querySelectorAll('.nav-subtree');
    const allToggles = document.querySelectorAll('.folder-toggle, .folder-toggle-only');
    
    allFolders.forEach(folder => {
        folder.classList.add('expanded');
    });
    
    allToggles.forEach(toggle => {
        toggle.setAttribute('aria-expanded', 'true');
        const toggleIcon = toggle.querySelector('.toggle-icon');
        if (toggleIcon) {
            toggleIcon.textContent = '▼';
        }
        
        // Save expanded state
        const targetId = toggle.getAttribute('data-target');
        if (targetId) {
            saveFolderState(targetId, true);
        }
    });
}

// Collapse all folders (utility function)
function collapseAllFolders() {
    const allFolders = document.querySelectorAll('.nav-subtree');
    const allToggles = document.querySelectorAll('.folder-toggle, .folder-toggle-only');
    
    allFolders.forEach(folder => {
        folder.classList.remove('expanded');
    });
    
    allToggles.forEach(toggle => {
        toggle.setAttribute('aria-expanded', 'false');
        const toggleIcon = toggle.querySelector('.toggle-icon');
        if (toggleIcon) {
            toggleIcon.textContent = '▶';
        }
        
        // Save collapsed state
        const targetId = toggle.getAttribute('data-target');
        if (targetId) {
            saveFolderState(targetId, false);
        }
    });
    
    // Re-expand folders containing current page
    setTimeout(initializeFolderStates, 100);
}

function openPrintView() {
    window.print();
}

function showToast(message, type = 'info') {
    // Create toast element
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    
    // Add styles
    toast.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: ${type === 'success' ? '#28a745' : type === 'error' ? '#dc3545' : '#007bff'};
        color: white;
        padding: 12px 24px;
        border-radius: 6px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        z-index: 10000;
        font-size: 14px;
        max-width: 300px;
        word-wrap: break-word;
        animation: slideInRight 0.3s ease-out;
    `;
    
    // Add CSS animation
    if (!document.querySelector('#toast-styles')) {
        const style = document.createElement('style');
        style.id = 'toast-styles';
        style.textContent = `
            @keyframes slideInRight {
                from { transform: translateX(100%); opacity: 0; }
                to { transform: translateX(0); opacity: 1; }
            }
            @keyframes slideOutRight {
                from { transform: translateX(0); opacity: 1; }
                to { transform: translateX(100%); opacity: 0; }
            }
        `;
        document.head.appendChild(style);
    }
    
    document.body.appendChild(toast);
    
    // Auto-remove after 4 seconds
    setTimeout(() => {
        toast.style.animation = 'slideOutRight 0.3s ease-in';
        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 300);
    }, 4000);
}