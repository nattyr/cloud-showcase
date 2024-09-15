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

async function insertVisitorNum() {
    const count = await getVisitorCount();
    const spanElement = document.getElementById(visitorNumSpanId);
    const textToInsert = count !== null ? count : '999';
    spanElement.textContent = textToInsert;
}

document.addEventListener('DOMContentLoaded', (event) => {
    insertVisitorNum();
});