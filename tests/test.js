const converter = require('../index.js');

async function test() {
    const html = `
        <table>
            <tr><td>Test</td></tr>
        </table>
    `;
    
    // Test PDF conversion
    const pdf = await converter.convertToPdf(html, {
        landscape: false,
        printBackground: true,
        marginTop: 10,
        marginBottom: 10,
        marginLeft: 10,
        marginRight: 10,
        pageSize: 'A4'
    });
    
    // Test Excel conversion
    const excel = await converter.convertToExcel(html);
    
    console.log('Tests passed!');
}

test().catch(console.error);