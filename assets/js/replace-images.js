function replaceImagePaths() {
    // Get all img elements in the current document
    const imgElements = document.querySelectorAll('img');
    
    let modifiedCount = 0;
    
    // Iterate through each img element
    imgElements.forEach(img => {
        // Skip images with class 'print-logo'
        if (img.classList.contains('print-logo')) {
            return;
        }
        
        const currentSrc = img.getAttribute('src');
        
        // Check if src attribute exists and starts with './'
        if (currentSrc && currentSrc.startsWith('./')) {
            // Replace './' at the beginning with '../'
            const newSrc = currentSrc.replace(/^\.\//, '../');
            
            // Update the src attribute
            img.setAttribute('src', newSrc);
            modifiedCount++;
        }
        
        // Set width to fit container width
        //img.style.width = '100%';
        //img.style.height = 'auto';
    });
    
    console.log(`Modified ${modifiedCount} image paths`);
    return modifiedCount;
}

// Automatically call the function when the document is fully loaded
document.addEventListener('DOMContentLoaded', function() {
    replaceImagePaths();
});