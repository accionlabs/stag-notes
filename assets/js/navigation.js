document.addEventListener('DOMContentLoaded', function() {
    
    // Log specific accion-collateral elements
    const accionFolder = document.querySelector('[data-path="accion-collateral"]');
    if (accionFolder) {
        const nameLink = accionFolder.querySelector('.folder-name-link');
        const toggle = accionFolder.querySelector('.folder-toggle, .folder-toggle-only');
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
            
            const targetId = this.getAttribute('data-target');
            const targetFolder = document.getElementById(targetId);
            const toggleIcon = this.querySelector('.toggle-icon');
            
            if (targetFolder) {
                const wasExpanded = targetFolder.classList.contains('expanded');
                targetFolder.classList.toggle('expanded');
                this.setAttribute('aria-expanded', targetFolder.classList.contains('expanded'));
                
                // Update toggle icon
                if (targetFolder.classList.contains('expanded')) {
                    toggleIcon.textContent = '▼';
                } else {
                    toggleIcon.textContent = '▶';
                }
                
                // Save folder state in localStorage
                saveFolderState(targetId, targetFolder.classList.contains('expanded'));
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
    
    // Auto-expand folders containing current page and restore saved states
    initializeFolderStates();
    
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
});

// Initialize folder states - restore from localStorage and auto-expand current path
function initializeFolderStates() {
    const currentLink = document.querySelector('.nav-link.current');
    const expandedFolders = new Set();
    
    // First, get saved folder states from localStorage
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

// Clear all saved folder states (utility function)
function clearFolderStates() {
    try {
        localStorage.removeItem('nav-folder-states');
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

// Make utility functions available globally for debugging/console use
window.navUtils = {
    expandAllFolders,
    collapseAllFolders,
    clearFolderStates,
    initializeFolderStates
};