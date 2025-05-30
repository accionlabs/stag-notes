document.addEventListener('DOMContentLoaded', function() {
    // Check for available export formats
    const exportContainer = document.getElementById('quarto-exports');
    if (!exportContainer) return;
    
    // Get the current page path and calculate export URLs
    const currentPath = window.location.pathname;
    
    let exportBasePath, documentName;
    
    if (currentPath.endsWith('/')) {
        // Remove trailing slash and get the document name
        const pathWithoutSlash = currentPath.slice(0, -1);
        const lastSlashIndex = pathWithoutSlash.lastIndexOf('/');
        exportBasePath = pathWithoutSlash.substring(0, lastSlashIndex + 1);
        documentName = pathWithoutSlash.substring(lastSlashIndex + 1);
    } else {
        // Fallback for paths without trailing slash
        const lastSlashIndex = currentPath.lastIndexOf('/');
        exportBasePath = currentPath.substring(0, lastSlashIndex + 1);
        documentName = currentPath.substring(lastSlashIndex + 1).replace(/\.html$/, '');
    }
    
    // Common export formats to check
    const exportFormats = [
        { ext: 'docx', icon: '📄', label: 'Word Document' },
        { ext: 'pptx', icon: '📊', label: 'PowerPoint' },
        { ext: 'pdf', icon: '📕', label: 'PDF Document' }
    ];
    
    // Check which export files exist
    exportFormats.forEach(format => {
        const filename = `${documentName}.${format.ext}`;
        const exportUrl = exportBasePath + filename;
        
        // Test if file exists
        fetch(exportUrl, { method: 'HEAD' })
            .then(response => {
                if (response.ok) {
                    // Create download button
                    const button = document.createElement('button');
                    button.className = 'export-btn';
                    button.innerHTML = `${format.icon} Download ${format.label}`;
                    button.onclick = () => {
                        const link = document.createElement('a');
                        link.href = exportUrl;
                        link.download = filename;
                        document.body.appendChild(link);
                        link.click();
                        document.body.removeChild(link);
                    };
                    exportContainer.appendChild(button);
                }
            })
            .catch(() => {
                // File doesn't exist or error occurred - do nothing
            });
    });
});