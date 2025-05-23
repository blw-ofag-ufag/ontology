// Global Declarations
let translations = {};  // Placeholder for fetched translations
let cropTypes = {};  // Store fetched crop types and emojis
const tableBody = document.querySelector('#cropsTable tbody');
const dataUrl = 'https://raw.githubusercontent.com/blw-ofag-ufag/ontology/main/mapping-tables/crops.json';
const urlParams = new URLSearchParams(window.location.search);
let lang = urlParams.get('lang') || 'de';
let originalData = [];  // Store the full unfiltered data globally
let activeSearchTerm = '';  // Store the current search term globally
let cropMap = {};  // Store crops by ID for lookup

// Fetch Translations on Page Load
function fetchTranslations() {
    return fetch('https://raw.githubusercontent.com/blw-ofag-ufag/ontology/refs/heads/main/docs/crop-table/translations.json')
        .then(response => {
            if (!response.ok) throw new Error('Failed to load translations');
            return response.json();
        })
        .then(data => {
            translations = data;
            applyTranslations(lang);  // Apply translations AFTER fetch
        })
        .catch(error => console.error('Error loading translations:', error));
}

// Apply Translations to Static Page Elements
function applyTranslations(lang) {
    const t = translations[lang] || translations['de'];  // Fallback to German if not found

    document.title = t.title;
    document.getElementById('titleHeading').textContent = t.title;
    document.getElementById('subtitle').innerHTML = t.subtitle;
    document.getElementById('searchInput').placeholder = t.search;

    const headers = t.columns;
    const thElements = document.querySelectorAll('#cropsTable thead th');

    thElements[0].textContent = headers[0];  // ID
    thElements[1].textContent = headers[1];  // Name
    thElements[2].textContent = headers[2];  // Parent
    thElements[3].textContent = headers[3];  // Parent
}

// Fetch and Populate Table
function fetchData() {
    return fetch(dataUrl)
        .then(response => response.json())
        .then(data => {
            originalData = data;  // Store full crop data

            // Build cropMap for quick parent lookup
            data.forEach(item => {
                cropMap[item['srppp-id']] = item.label?.[lang]?.[0] || `ID: ${item['srppp-id']}`;
            });

            renderTable(data);  // Render table after map is built
            applyURLParams();
        })
        .catch(error => console.error('Fehler beim Laden der Daten:', error));
}

// Separate table rendering into its own function, allowing us to call it repeatedly after filtering
function renderTable(data) {
    tableBody.innerHTML = '';  // Clear existing rows

    data.forEach(item => {
        const row = document.createElement('tr');

        // ID Column
        const idCell = document.createElement('td');
        idCell.textContent = item['srppp-id'] || '';
        row.appendChild(idCell);

        // Name Column (with tooltip)
        const nameCell = document.createElement('td');
        const names = item.label?.[lang] || [''];
        nameCell.innerHTML = formatNames(names);
        nameCell.setAttribute('data-title', buildTooltip(item, lang));
        row.appendChild(nameCell);

        // Parent Crop Column (NEW)
        const parentCell = document.createElement('td');
        const parentIds = item['srppp-parent-id'] || [];

        // Filter out parents that don't exist in cropMap
        const validParents = parentIds.filter(id => cropMap[id]);

        if (validParents.length > 0) {
            // Render clickable parent links
            parentCell.innerHTML = validParents.map(id => {
                const parentName = cropMap[id];
                return `<a href="#" class="parent-link" data-id="${id}">${parentName}</a>`;
            }).join(', ');
        } else {
            parentCell.textContent = '';  // No parent, or missing in cropMap
        }
        row.appendChild(parentCell);

        // Type Column (with emoji)
        const typeCell = document.createElement('td');
        const { emoji, tooltip } = getTypeEmoji(item.type);
        typeCell.textContent = emoji;
        typeCell.setAttribute('data-title', tooltip);
        row.appendChild(typeCell);

        tableBody.appendChild(row);
    });

    // Attach click listeners to parent links
    attachParentClickListeners();
}

// Handle Click Event on Parent Links
function attachParentClickListeners() {
    const parentLinks = document.querySelectorAll('.parent-link');

    parentLinks.forEach(link => {
        link.addEventListener('click', function (event) {
            event.preventDefault();
            const parentId = this.getAttribute('data-id');

            // Apply search filter for parent crop by ID
            activeSearchTerm = parentId;
            document.getElementById('searchInput').value = parentId;
            filterBySearch(parentId);

            // Update URL with parent ID as the search term
            urlParams.set('search', parentId);
            window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);
        });
    });
}

// Perform the search across all language labels in the JSON
function filterBySearch(term) {
    if (!term) {
        renderTable(originalData);  // Reset table if search is empty
        return;
    }

    // Split search term for multi-term filtering (OR, comma, |)
    const terms = term.split(/\s*[,|]\s*|\s*OR\s*/).filter(Boolean);
    const regex = new RegExp(terms.join('|'), 'i');  // Build regex for terms

    const filteredData = originalData.filter(item => {
        // Match by ID or by crop names
        const idMatch = item['srppp-id'].toString().includes(term);
        
        const nameMatch = Object.keys(item.label).some(langKey => {
            const names = item.label[langKey] || [];
            return names.some(name => 
                typeof name === 'string' && regex.test(name)
            );
        });

        return idMatch || nameMatch;  // Include if either name or ID matches
    });

    renderTable(filteredData);
}


// Fetch the Crop Types from JSON
function fetchCropTypes() {
    return fetch('https://raw.githubusercontent.com/blw-ofag-ufag/ontology/refs/heads/main/docs/crop-table/types.json')
        .then(response => {
            if (!response.ok) throw new Error('Failed to load crop types');
            return response.json();
        })
        .then(data => {
            cropTypes = data;  // Cache the crop types globally
        })
        .catch(error => {
            console.error('Error loading crop types:', error);
        });
}

// Format names for display (show preferred name only)
function formatNames(names) {
    return `<span class="preferred-name">${names[0]}</span>`;  // Only show the first name
}

// Map Crop Types to Emojis (Dynamic from JSON)
function getTypeEmoji(type) {
    const cropType = cropTypes[type];
    if (!cropType) return { emoji: '❓', tooltip: 'Unknown type' };

    const label = cropType.label?.[lang] || cropType.label?.['en'] || 'Unknown';
    const comment = cropType.comment?.[lang] || cropType.comment?.['en'] || '';
    const emoji = cropType.emoji || '❓';

    // Proper Tooltip with Label and Comment
    const tooltipContent = `
        <div class="type-name">${emoji} <b>${label}</b></div>
        <div class="type-comment">${comment || '-'}</div>
    `;

    return {
        emoji: emoji,
        tooltip: tooltipContent
    };
}

// Define buildTooltip for Tooltips
function buildTooltip(item, lang) {
    const names = item.label?.[lang] || [''];
    const latinNames = item.label?.['la'] || [];  // Latin names under "la"
    const comment = item.comment?.[lang] || '';

    const preferredName = names[0];
    const alternativeNames = names.slice(1).join(', ');

    // Tooltip Content (Build dynamically with graceful fallbacks)
    let tooltipContent = `<div class="type-name"><b>${preferredName}</b>`;

    // Join Latin names, but add parentheses only if they exist
    const latin = latinNames.join(', ');
    if (latin) {
        tooltipContent += ` <i>(${latin})</i>`;
    }
    tooltipContent += `</div>`;

    // Add alternative names if available
    if (alternativeNames) {
        tooltipContent += `
            <div><span class="alt-name">a.k.a. ${alternativeNames}</span></div>`;
    }

    // Add description (comment)
    if (comment) {
        tooltipContent += `
            <div class="type-comment">${comment}</div>`;
    }

    return tooltipContent;
}



// Apply Sorting and Search from URL
function applyURLParams() {
    const searchTerm = urlParams.get('search');
    const sortColumn = urlParams.get('sort');
    const sortDirection = urlParams.get('dir');
    if (searchTerm) {
        document.getElementById('searchInput').value = searchTerm;
        filterTable(searchTerm);
    }
    if (sortColumn !== null && sortDirection !== null) {
        sortTable(parseInt(sortColumn), true);
    }
}

// Initialize on Page Load
document.addEventListener('DOMContentLoaded', function () {
    // Wait for translations and crop types before fetching data
    Promise.all([fetchTranslations(), fetchCropTypes()])
        .then(() => {
            fetchData().then(() => {
                // Reapply search filter if search term is in URL
                const searchTermFromURL = urlParams.get('search');
                if (searchTermFromURL) {
                    activeSearchTerm = searchTermFromURL.trim();
                    document.getElementById('searchInput').value = activeSearchTerm;  // Reflect in UI
                    filterBySearch(activeSearchTerm);  // Apply search after data loads
                }
            });
        })
        .catch(error => console.error('Error during initialization:', error));
});

// Language Selection (Ensures Table Updates Properly)
document.getElementById('language').addEventListener('change', function () {
    lang = this.value;
    urlParams.set('lang', lang);

    // Update URL without reload
    window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);

    Promise.all([fetchTranslations(), fetchCropTypes()]).then(() => {
        fetchData().then(() => {
            // Reapply search filter if needed
            if (activeSearchTerm) {
                filterBySearch(activeSearchTerm);
            }

            // Reapply sorting if sort parameters exist
            const sortColumn = urlParams.get('sort');
            const sortDirection = urlParams.get('dir');

            if (sortColumn !== null && sortDirection !== null) {
                sortTable(parseInt(sortColumn), true);  // Preserve current direction
            }
        });
    });
});

// Attach URL Update to Search Event
document.getElementById('searchInput').addEventListener('input', function() {
    activeSearchTerm = this.value.trim();
    filterBySearch(activeSearchTerm);

    // Update URL with search parameter
    if (activeSearchTerm === '') {
        urlParams.delete('search');
    } else {
        urlParams.set('search', activeSearchTerm);
    }
    window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);
});

// Sort Table by Column
function sortTable(columnIndex, preserveDirection = false) {
    const table = document.getElementById('cropsTable');
    const headers = table.querySelectorAll('th');
    const rows = Array.from(table.rows).slice(1);
    let currentDirection = urlParams.get('dir') || 'asc';

    if (!preserveDirection) {
        // Toggle direction if not preserving current state
        currentDirection = currentDirection === 'asc' ? 'desc' : 'asc';
    }

    // Perform sorting
    rows.sort((a, b) =>
        a.cells[columnIndex].textContent.localeCompare(b.cells[columnIndex].textContent) *
        (currentDirection === 'asc' ? 1 : -1)
    );

    tableBody.innerHTML = '';  // Clear and append sorted rows
    rows.forEach(row => tableBody.appendChild(row));

    // Update URL to reflect sorting state
    urlParams.set('sort', columnIndex);
    urlParams.set('dir', currentDirection);
    window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);

    // Add sort indicator (triangle) to the sorted column
    headers.forEach(header => {
        const icon = header.querySelector('.sort-icon');
        if (icon) icon.innerHTML = '';  // Clear existing icons
    });

    let sortedHeader = headers[columnIndex].querySelector('.sort-icon');
    if (!sortedHeader) {
        headers[columnIndex].innerHTML += '<span class="sort-icon"></span>';
        sortedHeader = headers[columnIndex].querySelector('.sort-icon');
    }
    sortedHeader.innerHTML = currentDirection === 'asc' ? '▲' : '▼';
}

// Filter/Search Table and Update URL
function filterTable(searchTerm) {
    const rows = document.querySelectorAll('#cropsTable tbody tr');

    // Split search term by "OR", "|", or "," (we could further customize this)
    const terms = searchTerm.split(/\s*OR\s*|\s*\|\s*|,\s*/).filter(Boolean);

    // Build regex for case-insensitive matching
    const regex = new RegExp(terms.join('|'), 'i');

    // Apply filtering based on regex
    rows.forEach(row => {
        row.style.display = regex.test(row.textContent) ? '' : 'none';
    });

    // Update or remove the search parameter from the URL
    if (searchTerm.trim() === '') {
        urlParams.delete('search');
    } else {
        urlParams.set('search', searchTerm);
    }
    window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);
}

// Tooltip container
const tooltip = document.getElementById('tooltip');

// Show tooltip on hover (with multiline layout)
tableBody.addEventListener('mouseover', function (event) {
    const target = event.target;
    if (target.tagName === 'TD' && target.getAttribute('data-title')) {
        const tooltipText = target.getAttribute('data-title');
        const [label, comment, emoji] = tooltipText.split('|');

        tooltip.innerHTML = `
            <div class="type-name">${emoji} ${label}</div>
            <div class="type-comment">${comment}</div>
        `;

        tooltip.style.opacity = 1;
        tooltip.style.visibility = 'visible';
        positionTooltip(event);
    }
});

// Show tooltip on hover (for name and type)
tableBody.addEventListener('mouseover', function (event) {
    const target = event.target;
    if (target.tagName === 'TD' && target.getAttribute('data-title')) {
        tooltip.innerHTML = target.getAttribute('data-title');
        tooltip.style.opacity = 1;
        tooltip.style.visibility = 'visible';
        positionTooltip(event);
    }
});

// Hide tooltip and restore title on mouse leave (with fade-out delay)
tableBody.addEventListener('mouseout', function (event) {
    const target = event.target;
    if (target.tagName === 'TD' && target.getAttribute('data-title')) {
        tooltip.style.opacity = 0;
        tooltip.style.visibility = 'hidden';
    }
});

// Adjust tooltip position dynamically
tableBody.addEventListener('mousemove', positionTooltip);

function positionTooltip(event) {
    const offset = 15;
    tooltip.style.left = event.pageX + offset + 'px';
    tooltip.style.top = event.pageY + offset + 'px';
}
