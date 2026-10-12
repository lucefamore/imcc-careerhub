const FLOWISE_API_HOST = ''; // Example: https://flowise.example.com
const FLOWISE_CHATFLOW_ID = '';

if (!FLOWISE_API_HOST || !FLOWISE_CHATFLOW_ID) {
    console.info('[Flowise chat] Set FLOWISE_API_HOST and FLOWISE_CHATFLOW_ID in flowise-widget.js to enable the widget.');
} else {
    import('https://cdn.jsdelivr.net/npm/flowise-embed/dist/web.js')
        .then(function(module) {
            module.default.init({
                chatflowid: FLOWISE_CHATFLOW_ID,
                apiHost: FLOWISE_API_HOST,
                theme: {
                    button: {
                        backgroundColor: '#d94695',
                        right: 20,
                        bottom: 20,
                        size: 48,
                        iconColor: '#ffffff'
                    },
                    chatWindow: {
                        title: 'IMCC Careers Assistant',
                        welcomeMessage: 'Hello! How can I help with your career search today?',
                        backgroundColor: '#fffafc',
                        titleBackgroundColor: '#d94695',
                        titleTextColor: '#ffffff',
                        textColor: '#2b1f2f',
                        userMessageBackgroundColor: '#fce7f3',
                        userMessageTextColor: '#2b1f2f',
                        botMessageBackgroundColor: '#ffffff',
                        botMessageTextColor: '#2b1f2f'
                    }
                }
            });
        })
        .catch(function(error) {
            console.error('[Flowise chat] Failed to load the Flowise embed.', error);
        });
}
