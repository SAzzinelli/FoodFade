import Foundation

// MARK: - Open Food Facts API Models (definiti prima dell'actor per evitare problemi di isolamento)
struct OpenFoodFactsResponse: Sendable {
    let status: Int
    let product: Product?
    
    nonisolated init(status: Int, product: Product?) {
        self.status = status
        self.product = product
    }
}

struct Product: Sendable {
    let productName: String?
    let productNameEn: String?
    let productNameIt: String?
    let categories: String?
    let imageUrl: String?
    let imageFrontUrl: String?
    let imageFrontSmallUrl: String?
    let brands: String?
    let ingredientsText: String?
    let ingredientsTextIt: String?
    let quantity: String?
    
    nonisolated init(
        productName: String?,
        productNameEn: String?,
        productNameIt: String?,
        categories: String?,
        imageUrl: String?,
        imageFrontUrl: String?,
        imageFrontSmallUrl: String?,
        brands: String?,
        ingredientsText: String?,
        ingredientsTextIt: String?,
        quantity: String?
    ) {
        self.productName = productName
        self.productNameEn = productNameEn
        self.productNameIt = productNameIt
        self.categories = categories
        self.imageUrl = imageUrl
        self.imageFrontUrl = imageFrontUrl
        self.imageFrontSmallUrl = imageFrontSmallUrl
        self.brands = brands
        self.ingredientsText = ingredientsText
        self.ingredientsTextIt = ingredientsTextIt
        self.quantity = quantity
    }
}

/// Risultato della ricerca prodotto
struct ProductInfo: Sendable {
    let name: String
    let category: FoodCategory?
    let imageUrl: String?
    let brands: String?
    let ingredients: String?
    let quantity: String?
    
    nonisolated init(
        name: String,
        category: FoodCategory?,
        imageUrl: String? = nil,
        brands: String? = nil,
        ingredients: String? = nil,
        quantity: String? = nil
    ) {
        self.name = name
        self.category = category
        self.imageUrl = imageUrl
        self.brands = brands
        self.ingredients = ingredients
        self.quantity = quantity
    }
}

/// Helper per decodere la risposta fuori dal contesto actor
private func decodeOpenFoodFactsResponse(data: Data) async throws -> OpenFoodFactsResponse {
    // Decodifica direttamente nel Task.detached per evitare problemi di isolamento
    return try await Task.detached(priority: .userInitiated) { [data] in
        let decoder = JSONDecoder()
        // Decodifica usando una struct locale per evitare problemi di isolamento
        struct LocalResponse: Codable {
            let status: Int
            let product: LocalProduct?
            
            struct LocalProduct: Codable {
                let productName: String?
                let productNameEn: String?
                let productNameIt: String?
                let categories: String?
                let imageUrl: String?
                let imageFrontUrl: String?
                let imageFrontSmallUrl: String?
                let brands: String?
                let ingredientsText: String?
                let ingredientsTextIt: String?
                let quantity: String?
                
                enum CodingKeys: String, CodingKey {
                    case productName = "product_name"
                    case productNameEn = "product_name_en"
                    case productNameIt = "product_name_it"
                    case categories
                    case imageUrl = "image_url"
                    case imageFrontUrl = "image_front_url"
                    case imageFrontSmallUrl = "image_front_small_url"
                    case brands
                    case ingredientsText = "ingredients_text"
                    case ingredientsTextIt = "ingredients_text_it"
                    case quantity
                }
            }
        }
        
        let local = try decoder.decode(LocalResponse.self, from: data)
        return OpenFoodFactsResponse(
            status: local.status,
            product: local.product.map { p in
                Product(
                    productName: p.productName,
                    productNameEn: p.productNameEn,
                    productNameIt: p.productNameIt,
                    categories: p.categories,
                    imageUrl: p.imageUrl ?? p.imageFrontUrl ?? p.imageFrontSmallUrl,
                    imageFrontUrl: p.imageFrontUrl ?? p.imageFrontSmallUrl,
                    imageFrontSmallUrl: p.imageFrontSmallUrl,
                    brands: p.brands,
                    ingredientsText: p.ingredientsText ?? p.ingredientsTextIt,
                    ingredientsTextIt: p.ingredientsTextIt,
                    quantity: p.quantity
                )
            }
        )
    }.value
}

/// Servizio per la ricerca di prodotti tramite Open Food Facts API
actor FoodLookupService {
    private let baseURL = "https://world.openfoodfacts.org/api/v2/product"
    private var cache: [String: ProductInfo] = [:]
    
    /// Cerca un prodotto tramite barcode
    func lookupProduct(barcode: String) async throws -> ProductInfo? {
        // Controlla la cache
        if let cached = cache[barcode] {
            return cached
        }
        
        // Costruisci l'URL con i campi necessari per limitare la risposta
        let fields = "product_name,product_name_en,product_name_it,categories,image_url,image_front_url,image_front_small_url,brands,ingredients_text,ingredients_text_it,quantity"
        guard let encodedFields = fields.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/\(barcode).json?fields=\(encodedFields)") else {
            throw LookupError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("FoodFade iOS App - https://github.com/foodfade", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LookupError.invalidResponse
            }
            
            // Log per debug
            print("🔍 Open Food Facts API - Status Code: \(httpResponse.statusCode)")
            print("🔍 Open Food Facts API - Barcode: \(barcode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Open Food Facts API - Invalid status code: \(httpResponse.statusCode)")
                throw LookupError.invalidResponse
            }
            
            // Decode fuori dal contesto actor per evitare problemi con Swift 6
            let dataCopy = data
            let result = try await decodeOpenFoodFactsResponse(data: dataCopy)
            
            print("🔍 Open Food Facts API - Response status: \(result.status)")
            
            guard result.status == 1, let product = result.product else {
                print("❌ Open Food Facts API - Product not found or status != 1")
                // Log del JSON per debug
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Open Food Facts API - JSON response (first 500 chars): \(String(jsonString.prefix(500)))")
                }
                return nil
            }
            
            print("✅ Open Food Facts API - Product decoded successfully")
            print("   - productName: \(product.productName ?? "nil")")
            print("   - productNameIt: \(product.productNameIt ?? "nil")")
            print("   - imageUrl: \(product.imageUrl ?? "nil")")
            print("   - imageFrontUrl: \(product.imageFrontUrl ?? "nil")")
            print("   - brands: \(product.brands ?? "nil")")
            print("   - ingredientsText: \(product.ingredientsText?.prefix(50) ?? "nil")")
            
            // Preferisci il nome italiano, poi inglese, poi generico
            let productName = product.productNameIt ?? product.productName ?? product.productNameEn ?? "Prodotto sconosciuto"
            
            print("✅ Open Food Facts API - Product found: \(productName)")
            
            // Costruisci il nome completo con marca se disponibile
            let fullName: String
            if let brands = product.brands, !brands.isEmpty {
                fullName = "\(brands) - \(productName)"
            } else {
                fullName = productName
            }
            
            // Costruisci l'URL completo dell'immagine se disponibile
            // L'API di Open Food Facts restituisce già URL completi per le immagini
            // Priorità: image_url > image_front_url > image_front_small_url
            var imageUrlString: String? = nil
            
            // L'API restituisce già URL completi, quindi li usiamo direttamente
            if let imageUrl = product.imageUrl, !imageUrl.isEmpty {
                imageUrlString = imageUrl
                print("📷 Open Food Facts API - Usando image_url: \(imageUrl)")
            } else if let imageFrontUrl = product.imageFrontUrl, !imageFrontUrl.isEmpty {
                imageUrlString = imageFrontUrl
                print("📷 Open Food Facts API - Usando image_front_url: \(imageFrontUrl)")
            } else if let imageFrontSmallUrl = product.imageFrontSmallUrl, !imageFrontSmallUrl.isEmpty {
                imageUrlString = imageFrontSmallUrl
                print("📷 Open Food Facts API - Usando image_front_small_url: \(imageFrontSmallUrl)")
            } else {
                // Fallback: costruisci l'URL dal barcode se non c'è un URL diretto
                // Formato: https://images.openfoodfacts.org/images/products/{barcode}/front.{size}.jpg
                let barcodeDigits = barcode.prefix(13)
                if barcodeDigits.count >= 8 {
                    let path = String(barcodeDigits)
                    // Formatta il barcode: 8013355999143 -> 801/335/599/9143
                    let formattedPath = path.enumerated().map { index, char in
                        index > 0 && index % 3 == 0 ? "/\(char)" : "\(char)"
                    }.joined()
                    imageUrlString = "https://images.openfoodfacts.org/images/products/\(formattedPath)/front.400.jpg"
                    print("📷 Open Food Facts API - Costruito URL fallback: \(imageUrlString ?? "nil")")
                }
            }
            
            let productInfo = ProductInfo(
                name: fullName,
                category: mapCategory(product.categories),
                imageUrl: imageUrlString,
                brands: product.brands,
                ingredients: product.ingredientsTextIt ?? product.ingredientsText,
                quantity: product.quantity
            )
            
            print("✅ Open Food Facts API - ProductInfo created: \(fullName)")
            
            // Salva nella cache
            cache[barcode] = productInfo
            
            return productInfo
        } catch {
            throw LookupError.networkError(error)
        }
    }
    
    /// Mappa le categorie di Open Food Facts alle nostre categorie
    private func mapCategory(_ categories: String?) -> FoodCategory? {
        guard let categories = categories?.lowercased() else { return nil }
        
        if categories.contains("frozen") || categories.contains("congelat") {
            return .freezer
        } else if categories.contains("fridge") || categories.contains("frigo") || 
                  categories.contains("dairy") || categories.contains("latticin") ||
                  categories.contains("fresh") || categories.contains("fresco") {
            return .fridge
        } else {
            return .pantry
        }
    }
    
    enum LookupError: LocalizedError {
        case invalidURL
        case invalidResponse
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "URL non valido"
            case .invalidResponse:
                return "Risposta non valida dal server"
            case .networkError(let error):
                return "Errore di rete: \(error.localizedDescription)"
            }
        }
    }
}

