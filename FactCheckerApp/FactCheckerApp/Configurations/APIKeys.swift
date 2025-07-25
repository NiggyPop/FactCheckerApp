import Foundation

struct APIKeys {
    // Add your API keys here
    let newsAPIKey: String? = "YOUR_NEWS_API_KEY"
    let googleFactCheckAPIKey: String? = "YOUR_GOOGLE_FACT_CHECK_API_KEY"
    let googleSearchAPIKey: String? = "YOUR_GOOGLE_SEARCH_API_KEY"
    let customSearchEngineID: String? = "YOUR_CUSTOM_SEARCH_ENGINE_ID"
    
    // OpenAI API for enhanced NLP (optional)
    let openAIAPIKey: String? = "YOUR_OPENAI_API_KEY"
    
    // Azure Cognitive Services (optional)
    let azureSpeechKey: String? = "YOUR_AZURE_SPEECH_KEY"
    let azureSpeechRegion: String? = "YOUR_AZURE_REGION"
    
    static let shared = APIKeys()
    
    private init() {}
}
