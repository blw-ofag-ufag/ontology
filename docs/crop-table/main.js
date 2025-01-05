// Global Declarations
let translations = {};  // Placeholder for fetched translations
const tableBody = document.querySelector('#cropsTable tbody');
const dataUrl = 'https://raw.githubusercontent.com/blw-ofag-ufag/ontology/main/mapping-tables/crops.json';
const urlParams = new URLSearchParams(window.location.search);
let lang = urlParams.get('lang') || 'de';

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
    document.getElementById('col1').textContent = headers[0];
    document.getElementById('col2').textContent = headers[1];
    document.getElementById('col3').textContent = headers[2];
    document.getElementById('col4').textContent = headers[3];
}

// Fetch and Populate Table
function fetchData() {
    fetch(dataUrl)
        .then(response => response.json())
        .then(data => {
            tableBody.innerHTML = '';  // Clear table

            data.forEach(item => {
                const row = document.createElement('tr');

                const idCell = document.createElement('td');
                idCell.textContent = item['srppp-id'] || '';
                row.appendChild(idCell);

                const nameCell = document.createElement('td');
                const names = item.label?.[lang] || [''];
                nameCell.innerHTML = formatNames(names);  // Format and insert names
                row.appendChild(nameCell);

                const commentCell = document.createElement('td');
                commentCell.textContent = item.comment?.[lang] || '';
                row.appendChild(commentCell);

                const typeCell = document.createElement('td');
                typeCell.textContent = getTypeEmoji(item.type);
                row.appendChild(typeCell);

                tableBody.appendChild(row);
            });

            applyURLParams();  // Apply search and sort from URL
        })
        .catch(error => console.error('Fehler beim Laden der Daten:', error));
}

// Format names for display (highlight first, fade rest)
function formatNames(names) {
    if (names.length === 1) return names[0];  // Single name, no formatting

    const preferred = `<span class="preferred-name">${names[0]}</span>`;
    const alternates = names.slice(1)
        .map(name => `<span class="alt-name">${name}</span>`)
        .join('<span class="alt-name">, </span>');
    return `${preferred}${alternates ? '<span class="alt-name">, </span>' + alternates : ''}`;
}

// Map Crop Types to Emojis
function getTypeEmoji(type) {
    const typeMapping = {
        arable: '🌽',
        medical: '🌿',
        vegetable: '🥬',
        fruit: '🍎',
        berry: '🫐',
        viticulture: '🍇',
        ornamental: '🌺',
        forestry: '🌲',
        noncrop: '🏭',
        varia: '🌱'
    };
    return typeMapping[type] || '';
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
    fetchTranslations().then(() => {
        fetchData();
    });
    document.getElementById('language').value = lang;
});

// Language Selection (Ensures Table Updates Properly)
document.getElementById('language').addEventListener('change', function () {
    lang = this.value;
    urlParams.set('lang', lang);

    // Update URL without reload
    window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);

    // Fetch translations first, then reload the table
    fetchTranslations().then(() => {
        fetchData();
    });
});

// Attach URL Update to Search Event
document.getElementById('searchInput').addEventListener('input', function() {
    const searchTerm = this.value;
    filterTable(searchTerm);
});

// Sort Table by Column
function sortTable(columnIndex, preserveDirection = false) {
    const table = document.getElementById('cropsTable');
    const headers = table.querySelectorAll('th');  // Select all headers
    const rows = Array.from(table.rows).slice(1);
    let currentDirection = urlParams.get('dir') || 'asc';

    // Toggle direction unless preserving
    if (!preserveDirection) {
        currentDirection = currentDirection === 'asc' ? 'desc' : 'asc';
    }

    // Sort rows based on direction
    rows.sort((a, b) =>
        a.cells[columnIndex].textContent.localeCompare(b.cells[columnIndex].textContent)
        * (currentDirection === 'asc' ? 1 : -1)
    );

    tableBody.innerHTML = '';
    rows.forEach(row => tableBody.appendChild(row));

    // Update URL with new sorting state
    urlParams.set('sort', columnIndex);
    urlParams.set('dir', currentDirection);
    window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);

    // Clear existing sort indicators
    headers.forEach(header => {
        const icon = header.querySelector('.sort-icon');
        if (icon) icon.innerHTML = '';
    });

    // Add sort indicator to the sorted column
    const sortedHeader = headers[columnIndex].querySelector('.sort-icon');
    if (sortedHeader) {
        sortedHeader.innerHTML = currentDirection === 'asc' ? '▲' : '▼';
    }
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
