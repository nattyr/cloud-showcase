const endpointUrl = 'https://ailrk7s7o6.execute-api.ap-southeast-2.amazonaws.com/prod/hit';
const apiKey = 'r7H4QnEkFY2GPNTW7ykQD1HiZ3QQomlsaszYMhqF';

const visitorNumSpanId = 'visitor_num';

async function getVisitorCount() {
    try {
        const response = await fetch(endpointUrl, {
            method: 'GET',
            headers: {
                'x-api-key': apiKey
            }
        });

        const data = await response.json();
        return (data.count);
    } catch (e) {
        console.error('Error in getVisitorCount():', e)
        return null;
    }
}

function getNumberWithOrdinal(n) {
    var s = ["th", "st", "nd", "rd"],
        v = n % 100;
    return n + (s[(v - 20) % 10] || s[v] || s[0]);
}

async function insertVisitorNum() {
    const count = await getVisitorCount();
    const spanElement = document.getElementById(visitorNumSpanId);
    const textToInsert = count !== null ? getNumberWithOrdinal(count) : '999th';
    spanElement.textContent = textToInsert;
}

document.addEventListener('DOMContentLoaded', (event) => {
    insertVisitorNum();
});