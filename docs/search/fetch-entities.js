let timeout;

function getSelectedLanguage() {
  const radios = document.querySelectorAll('input[name="language"]');
  for (const radio of radios) {
    if (radio.checked) {
      return radio.value;
    }
  }
  return "de";
}

async function fetchEntities(query) {
  const language = getSelectedLanguage();
  const sparqlQuery = `
    PREFIX schema: <http://schema.org/>  
    SELECT ?entity ?label
    WHERE {
      ?entity schema:name ?label .
      FILTER(LANG(?label) = "${language}") .
      FILTER(REGEX(?label, "${query}", "i")).
    }
    LIMIT 5
  `;
  const endpointUrl = "https://lindas.admin.ch/query";
  const fullUrl = `${endpointUrl}?query=${encodeURIComponent(sparqlQuery)}&format=json`;
  try {
    const response = await fetch(fullUrl, {
      headers: { Accept: "application/sparql-results+json" },
    });
    if (!response.ok) {
      console.error("SPARQL request failed:", response.statusText);
      return [];
    }
    const data = await response.json();
    return data.results.bindings.map(item => ({
      id: item.entity.value,
      label: item.label.value
    }));
  } catch (error) {
    console.error("Error fetching SPARQL data:", error);
    return [];
  }
}

async function fetchFullEntities(query) {
  const language = getSelectedLanguage();
  const sparqlQuery = `
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    PREFIX schema: <http://schema.org/>  
    SELECT ?entity ?label ?types
    WHERE {
        ?entity schema:name ?label .
        FILTER(LANG(?label) = "${language}") .
        FILTER(REGEX(?label, "${query}", "i")).
        OPTIONAL {
            SELECT DISTINCT ?entity (GROUP_CONCAT(?typeName; SEPARATOR=", ") AS ?types)
            WHERE {
                ?entity a ?type .
                ?type rdfs:label ?typeName .
            }
            GROUP BY ?entity
        }
    }
  `;
  const endpointUrl = "https://lindas.admin.ch/query";
  const fullUrl = `${endpointUrl}?query=${encodeURIComponent(sparqlQuery)}&format=json`;

  try {
    const response = await fetch(fullUrl, {
      headers: { Accept: "application/sparql-results+json" },
    });
    if (!response.ok) {
      console.error("SPARQL request failed:", response.statusText);
      return [];
    }
    const data = await response.json();
    return data.results.bindings.map(item => ({
      id: item.entity.value,
      label: item.label.value,
      types: item.types ? item.types.value : "No types available"
    }));
  } catch (error) {
    console.error("Error fetching SPARQL data:", error);
    return [];
  }
}

function debounce(func, delay) {
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), delay);
  };
}

function renderSuggestions(suggestions, container) {
  container.innerHTML = ""; // Clear previous suggestions

  if (suggestions.length === 0) {
    const noResults = document.createElement("div");
    noResults.className = "no-results";
    noResults.textContent = "No results found.";
    container.appendChild(noResults);
    return;
  }

  suggestions.forEach(suggestion => {
    const suggestionElement = document.createElement("div");
    suggestionElement.className = "suggestion";
    suggestionElement.innerHTML = `
      <strong>${suggestion.label}</strong><br>
      <small><a href="${suggestion.id}" target="_blank">${suggestion.id}</a></small>
    `;
    container.appendChild(suggestionElement);
  });
}

function renderTable(results) {
  const tableContainer = document.getElementById("resultsTable");
  tableContainer.innerHTML = ""; // Clear previous table or loading message

  if (results.length === 0) {
    tableContainer.textContent = "No results found.";
    return;
  }

  const table = document.createElement("table");
  table.className = "entity-table";

  // Create header row
  const thead = document.createElement("thead");
  const headerRow = document.createElement("tr");
  const headers = ["Name and IRI", "Types"];
  headers.forEach(h => {
    const th = document.createElement("th");
    th.textContent = h;
    headerRow.appendChild(th);
  });
  thead.appendChild(headerRow);
  table.appendChild(thead);

  // Create body rows
  const tbody = document.createElement("tbody");
  results.forEach(item => {
    const row = document.createElement("tr");

    const nameIriTd = document.createElement("td");
    nameIriTd.innerHTML = `
      <strong>${item.label}</strong><br>
      <small><a href="${item.id}" target="_blank">${item.id}</a></small>
    `;
    row.appendChild(nameIriTd);

    const typesTd = document.createElement("td");
    typesTd.textContent = item.types;
    row.appendChild(typesTd);

    tbody.appendChild(row);
  });
  table.appendChild(tbody);

  tableContainer.appendChild(table);
}

async function handleInput(event) {
  const query = event.target.value.trim();
  const suggestionsContainer = document.getElementById("suggestions");

  if (query.length < 2) {
    suggestionsContainer.innerHTML = ""; // Clear suggestions if query is too short
    return;
  }

  const suggestions = await fetchEntities(query);
  renderSuggestions(suggestions, suggestionsContainer);
}

async function handleEnterKey(event) {
  if (event.key === "Enter") {
    const query = event.target.value.trim();
    if (query.length < 2) {
      return; // Only show table if query is at least 2 chars long
    }

    // Update the URL to include the query parameter
    const newUrl = new URL(window.location.href);
    newUrl.searchParams.set('query', query);
    window.history.pushState({}, '', newUrl);

    // Clear suggestions when ENTER is pressed
    const suggestionsContainer = document.getElementById("suggestions");
    suggestionsContainer.innerHTML = "";

    // Show a smaller, centered loading gif in the resultsTable
    const tableContainer = document.getElementById("resultsTable");
    tableContainer.innerHTML = '<img src="loading.gif" alt="Loading..." style="display:block; margin:20px auto; width:32px; height:32px;" />';

    const results = await fetchFullEntities(query);
    renderTable(results);
  }
}

document.addEventListener("DOMContentLoaded", async () => {
  const searchInput = document.getElementById("search");
  const params = new URLSearchParams(window.location.search);
  const storedQuery = params.get('query');

  // If there’s a stored query in the URL, display loading and fetch results immediately
  if (storedQuery && storedQuery.trim().length >= 2) {
    searchInput.value = storedQuery;
    const tableContainer = document.getElementById("resultsTable");
    tableContainer.innerHTML = '<img src="loading.gif" alt="Loading..." style="display:block; margin:20px auto; width:32px; height:32px;" />';
    const results = await fetchFullEntities(storedQuery);
    renderTable(results);
  }

  searchInput.addEventListener("input", debouncedHandleInput);
  searchInput.addEventListener("keydown", handleEnterKey);
});

const debouncedHandleInput = debounce(handleInput, 50);

document.addEventListener("DOMContentLoaded", () => {
  const searchInput = document.getElementById("search");
  searchInput.addEventListener("input", debouncedHandleInput);
  searchInput.addEventListener("keydown", handleEnterKey);
});

