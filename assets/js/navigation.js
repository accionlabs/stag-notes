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

// Export Functions
function exportToHTML() {
    const content = document.querySelector('.content').innerHTML;
    const title = document.querySelector('h1') ? document.querySelector('h1').textContent : 'Document';
    
    const htmlContent = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title}</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 800px; 
            margin: 0 auto; 
            padding: 40px 20px;
            line-height: 1.6;
            color: #333;
        }
        h1, h2, h3, h4, h5, h6 { 
            color: #1f2328;
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
        }
        h1 { 
            font-size: 2rem;
            border-bottom: 1px solid #e1e4e8;
            padding-bottom: 8px;
        }
        h2 { 
            font-size: 1.5rem;
            border-bottom: 1px solid #e1e4e8;
            padding-bottom: 4px;
        }
        p { margin-bottom: 16px; }
        pre { 
            background: #f6f8fa;
            padding: 16px;
            border-radius: 6px;
            overflow-x: auto;
            border: 1px solid #e1e4e8;
        }
        code { 
            background: #f6f8fa;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'SFMono-Regular', Consolas, monospace;
            font-size: 0.9em;
        }
        pre code {
            background: none;
            padding: 0;
        }
        blockquote { 
            border-left: 4px solid #d1d5da;
            margin: 16px 0;
            padding: 0 16px;
            color: #666;
        }
        table { 
            border-collapse: collapse;
            width: 100%;
            margin: 16px 0;
        }
        th, td { 
            border: 1px solid #e1e4e8;
            padding: 8px 12px;
            text-align: left;
        }
        th { 
            background-color: #f6f8fa;
            font-weight: 600;
        }
        ul, ol { 
            margin: 16px 0;
            padding-left: 32px;
        }
        li { margin-bottom: 8px; }
        a { 
            color: #0366d6;
            text-decoration: none;
        }
        a:hover { text-decoration: underline; }
        .mermaid { 
            text-align: center;
            margin: 20px 0;
        }
        .export-options { display: none; }
        .no-print { display: none; }
    </style>
</head>
<body>
    ${content}
</body>
</html>`;
    
    const blob = new Blob([htmlContent], { type: 'text/html' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${title.replace(/[^a-z0-9\s]/gi, '').replace(/\s+/g, '_')}.html`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

async function exportWithMermaid() {
    // Wait for mermaid to fully render
    await new Promise(resolve => setTimeout(resolve, 1500));
    
    const content = document.querySelector('.content').cloneNode(true);
    const title = document.querySelector('h1') ? document.querySelector('h1').textContent : 'Document';
    
    // Remove export options from cloned content
    const exportOptions = content.querySelector('.export-options');
    if (exportOptions) {
        exportOptions.remove();
    }
    
    // Convert mermaid SVGs to images
    const mermaidElements = content.querySelectorAll('.mermaid svg');
    
    for (let svg of mermaidElements) {
        try {
            // Get the SVG dimensions
            const svgRect = svg.getBoundingClientRect();
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            
            // Set canvas size
            canvas.width = svgRect.width || 800;
            canvas.height = svgRect.height || 600;
            
            // Convert SVG to string
            const svgData = new XMLSerializer().serializeToString(svg);
            const svgBlob = new Blob([svgData], { type: 'image/svg+xml;charset=utf-8' });
            const url = URL.createObjectURL(svgBlob);
            
            // Create image from SVG
            const img = new Image();
            await new Promise((resolve, reject) => {
                img.onload = () => {
                    // Draw to canvas
                    ctx.fillStyle = 'white';
                    ctx.fillRect(0, 0, canvas.width, canvas.height);
                    ctx.drawImage(img, 0, 0);
                    
                    // Create new image element
                    const imgElement = document.createElement('img');
                    imgElement.src = canvas.toDataURL('image/png');
                    imgElement.style.maxWidth = '100%';
                    imgElement.style.height = 'auto';
                    imgElement.alt = 'Mermaid Diagram';
                    
                    // Replace SVG with image
                    svg.parentNode.replaceChild(imgElement, svg);
                    URL.revokeObjectURL(url);
                    resolve();
                };
                img.onerror = reject;
                img.src = url;
            });
        } catch (error) {
            console.warn('Failed to convert mermaid diagram:', error);
            // Keep original SVG if conversion fails
        }
    }
    
    // Export the content with converted diagrams
    const htmlContent = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title}</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 800px; 
            margin: 0 auto; 
            padding: 40px 20px;
            line-height: 1.6;
            color: #333;
        }
        h1, h2, h3, h4, h5, h6 { 
            color: #1f2328;
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
        }
        h1 { 
            font-size: 2rem;
            border-bottom: 1px solid #e1e4e8;
            padding-bottom: 8px;
        }
        h2 { 
            font-size: 1.5rem;
            border-bottom: 1px solid #e1e4e8;
            padding-bottom: 4px;
        }
        p { margin-bottom: 16px; }
        pre { 
            background: #f6f8fa;
            padding: 16px;
            border-radius: 6px;
            overflow-x: auto;
            border: 1px solid #e1e4e8;
        }
        code { 
            background: #f6f8fa;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'SFMono-Regular', Consolas, monospace;
            font-size: 0.9em;
        }
        pre code {
            background: none;
            padding: 0;
        }
        blockquote { 
            border-left: 4px solid #d1d5da;
            margin: 16px 0;
            padding: 0 16px;
            color: #666;
        }
        table { 
            border-collapse: collapse;
            width: 100%;
            margin: 16px 0;
        }
        th, td { 
            border: 1px solid #e1e4e8;
            padding: 8px 12px;
            text-align: left;
        }
        th { 
            background-color: #f6f8fa;
            font-weight: 600;
        }
        ul, ol { 
            margin: 16px 0;
            padding-left: 32px;
        }
        li { margin-bottom: 8px; }
        a { 
            color: #0366d6;
            text-decoration: none;
        }
        a:hover { text-decoration: underline; }
        img { 
            max-width: 100%;
            height: auto;
            display: block;
            margin: 20px auto;
        }
        .export-options { display: none; }
        .no-print { display: none; }
    </style>
</head>
<body>
    ${content.innerHTML}
</body>
</html>`;
    
    const blob = new Blob([htmlContent], { type: 'text/html' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${title.replace(/[^a-z0-9\s]/gi, '').replace(/\s+/g, '_')}_with_diagrams.html`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

function copyToClipboard() {
    const content = document.querySelector('.content');
    
    // Create a temporary element with clean content
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = content.innerHTML;
    
    // Remove export options from copied content
    const exportOptions = tempDiv.querySelector('.export-options');
    if (exportOptions) {
        exportOptions.remove();
    }
    
    // Remove no-print elements
    const noPrintElements = tempDiv.querySelectorAll('.no-print');
    noPrintElements.forEach(el => el.remove());
    
    // Select and copy
    document.body.appendChild(tempDiv);
    const range = document.createRange();
    range.selectNode(tempDiv);
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    
    try {
        const successful = document.execCommand('copy');
        if (successful) {
            // Show success message
            showToast('Content copied! You can now paste it into Google Docs or any editor.', 'success');
        } else {
            showToast('Copy failed. Please select and copy manually.', 'error');
        }
    } catch (err) {
        showToast('Copy not supported. Please select and copy manually.', 'error');
    }
    
    selection.removeAllRanges();
    document.body.removeChild(tempDiv);
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