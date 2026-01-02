//
//  PortugueseAutocorrectService.swift
//  SwiftSpeak
//
//  Portuguese language autocorrection service
//  Handles diacritic restoration (accents, tildes, cedillas), proper nouns, and common corrections
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

/// Portuguese autocorrection service for intelligent Portuguese text correction
enum PortugueseAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Portuguese word - restores diacritics and applies corrections
    /// Returns nil if no correction needed
    static func fixPortugueseWord(_ word: String) -> String? {
        let lowercased = word.lowercased()

        // Check for diacritic corrections (most common need)
        if let corrected = portugueseDiacritics[lowercased] {
            return preserveCase(original: word, corrected: corrected)
        }

        // Check for proper nouns (cities, countries, etc.)
        if let properNoun = portugueseProperNouns[lowercased] {
            return properNoun
        }

        return nil
    }

    /// Check if word should be capitalized (Portuguese proper nouns)
    static func shouldCapitalizePortuguese(_ word: String) -> String? {
        let lowercased = word.lowercased()
        return portugueseProperNouns[lowercased]
    }

    // MARK: - Helper Methods

    /// Preserve the original case pattern when applying correction
    private static func preserveCase(original: String, corrected: String) -> String {
        guard !original.isEmpty, !corrected.isEmpty else { return corrected }

        let isAllCaps = original == original.uppercased() && original.count > 1
        let isCapitalized = original.first?.isUppercase ?? false

        if isAllCaps {
            return corrected.uppercased()
        } else if isCapitalized {
            return corrected.prefix(1).uppercased() + corrected.dropFirst()
        }
        return corrected
    }

    // MARK: - Portuguese Diacritics Dictionary
    // Words typed without Portuguese characters -> correct form with diacritics

    private static let portugueseDiacritics: [String: String] = [
        // ==========================================
        // ACUTE ACCENTS (most common)
        // ==========================================

        // Common verbs with acute accent
        "voce": "você", "voces": "vocês",
        "e": "é",  // "is" - context dependent but very common
        "esta": "está", "estao": "estão", "estarei": "estarei",
        "estara": "estará", "estamos": "estamos",
        "sera": "será", "serao": "serão",
        "tera": "terá", "terao": "terão",
        "fara": "fará", "farao": "farão",
        "ira": "irá", "irao": "irão",
        "dara": "dará", "darao": "darão",
        "vira": "virá", "virao": "virão",
        "podera": "poderá", "poderao": "poderão",
        "devera": "deverá", "deverao": "deverão",
        "sabera": "saberá", "saberao": "saberão",
        "ha": "há",  // "there is"
        "so": "só",  // "only"
        "ja": "já",  // "already"
        "la": "lá",  // "there"
        "ca": "cá",  // "here"
        "atras": "atrás",
        "apos": "após",
        "atraves": "através",
        "detras": "detrás",
        "pos": "pós",
        "pre": "pré",
        "ate": "até",
        "avo": "avó", "avos": "avós",  // grandmother
        "bebe": "bebê",  // baby (Brazilian)
        "cafe": "café",
        "papai": "papai", "mamae": "mamãe",
        "vovo": "vovó", "vova": "vovó",

        // Common words with acute accent
        "tambem": "também",
        "alem": "além",
        "alguem": "alguém",
        "ninguem": "ninguém",
        "porem": "porém",
        "refem": "refém",
        "trem": "trem",  // no accent in Brazilian Portuguese
        "ontem": "ontem",  // no accent
        "agua": "água",
        "duvida": "dúvida",
        "unico": "único", "unica": "única",
        "rapido": "rápido", "rapida": "rápida",
        "facil": "fácil",
        "dificil": "difícil",
        "impossivel": "impossível",
        "possivel": "possível",
        "incrivel": "incrível",
        "horrivel": "horrível",
        "terrivel": "terrível",
        "visivel": "visível",
        "fragil": "frágil",
        "util": "útil",
        "inutel": "inútil",
        "movel": "móvel",
        "imovel": "imóvel",
        "numero": "número",
        "publico": "público", "publica": "pública",
        "politica": "política", "politico": "político",
        "economico": "econômico", "economica": "econômica",
        "historico": "histórico", "historica": "histórica",
        "pratico": "prático", "pratica": "prática",
        "logico": "lógico", "logica": "lógica",
        "magico": "mágico", "magica": "mágica",
        "tragico": "trágico", "tragica": "trágica",
        "comico": "cômico", "comica": "cômica",
        "medico": "médico", "medica": "médica",
        "musica": "música",
        "classico": "clássico", "classica": "clássica",
        "basico": "básico", "basica": "básica",
        "tecnico": "técnico", "tecnica": "técnica",
        "especifico": "específico", "especifica": "específica",
        "ultimo": "último", "ultima": "última",
        "proximo": "próximo", "proxima": "próxima",
        "otimo": "ótimo", "otima": "ótima",
        "pessimo": "péssimo", "pessima": "péssima",
        "minimo": "mínimo", "minima": "mínima",
        "maximo": "máximo", "maxima": "máxima",
        "intimo": "íntimo", "intima": "íntima",
        "obvio": "óbvio", "obvia": "óbvia",
        "serio": "sério", "seria": "séria",
        "necessario": "necessário", "necessaria": "necessária",
        "contrario": "contrário", "contraria": "contrária",
        "secretaria": "secretária",
        "funcionario": "funcionário", "funcionaria": "funcionária",
        "calendario": "calendário",
        "vocabulario": "vocabulário",
        "dicionario": "dicionário",
        "horario": "horário",
        "salario": "salário",
        "aniversario": "aniversário",
        "beneficio": "benefício",
        "exercicio": "exercício",
        "edificio": "edifício",
        "principio": "princípio",
        "comercio": "comércio",
        "negocio": "negócio",

        // ==========================================
        // TILDE (~) - ão, ã, õe, ões
        // ==========================================

        // Words ending in -ão
        "nao": "não",
        "entao": "então",
        "acao": "ação", "acoes": "ações",
        "situacao": "situação", "situacoes": "situações",
        "informacao": "informação", "informacoes": "informações",
        "comunicacao": "comunicação",
        "educacao": "educação",
        "organizacao": "organização",
        "administracao": "administração",
        "producao": "produção",
        "construcao": "construção",
        "solucao": "solução", "solucoes": "soluções",
        "razao": "razão", "razoes": "razões",
        "opiniao": "opinião", "opinioes": "opiniões",
        "funcao": "função", "funcoes": "funções",
        "direcao": "direção",
        "atencao": "atenção",
        "relacao": "relação", "relacoes": "relações",
        "posicao": "posição", "posicoes": "posições",
        "condicao": "condição", "condicoes": "condições",
        "tradicao": "tradição",
        "emocao": "emoção", "emocoes": "emoções",
        "decisao": "decisão", "decisoes": "decisões",
        "discussao": "discussão",
        "sessao": "sessão",
        "impressao": "impressão",
        "expressao": "expressão",
        "profissao": "profissão",
        "missao": "missão",
        "permissao": "permissão",
        "paixao": "paixão",
        "cancao": "canção", "cancoes": "canções",
        "licao": "lição", "licoes": "lições",
        "coracao": "coração", "coracoes": "corações",
        "irmao": "irmão", "irmaos": "irmãos",
        "irma": "irmã", "irmas": "irmãs",
        "mae": "mãe", "maes": "mães",
        "pao": "pão", "paes": "pães",
        "cao": "cão", "caes": "cães",
        "alemao": "alemão", "alemaes": "alemães", "alema": "alemã",
        "mao": "mão", "maos": "mãos",
        "cidadao": "cidadão", "cidadaos": "cidadãos",
        "capitao": "capitão", "capitaes": "capitães",
        "campeao": "campeão", "campeoes": "campeões",
        "verao": "verão",
        "aviação": "aviação",
        "estacao": "estação", "estacoes": "estações",
        "aviao": "avião", "avioes": "aviões",
        "botao": "botão", "botoes": "botões",
        "limao": "limão", "limoes": "limões",
        "melao": "melão", "meloes": "melões",
        "mamao": "mamão", "mamoes": "mamões",
        "feijao": "feijão",
        "sertao": "sertão",
        "grao": "grão", "graos": "grãos",
        "orgao": "órgão", "orgaos": "órgãos",
        "sotao": "sótão",

        // Words with ã in the middle
        "amanha": "amanhã",
        "roma": "romã",  // pomegranate
        "la": "lã",  // wool (context dependent)
        "crista": "cristã", "cristaos": "cristãos",
        "maca": "maçã", "macas": "maçãs",

        // Words with õe/ões
        "avioes": "aviões",
        "eleicoes": "eleições",
        "reunioes": "reuniões",
        "promocoes": "promoções",
        "excecoes": "exceções",
        "explicacoes": "explicações",

        // ==========================================
        // CEDILLA (ç)
        // ==========================================

        "voce": "você",
        "franca": "França",
        "frances": "francês", "francesa": "francesa",
        "ingles": "inglês", "inglesa": "inglesa",
        "portugues": "português", "portuguesa": "portuguesa",
        "holandes": "holandês", "holandesa": "holandesa",
        "japones": "japonês", "japonesa": "japonesa",
        "chines": "chinês", "chinesa": "chinesa",
        "coreano": "coreano",
        "preco": "preço", "precos": "preços",
        "servico": "serviço", "servicos": "serviços",
        "espaco": "espaço", "espacos": "espaços",
        "endereco": "endereço", "enderecos": "endereços",
        "cabeca": "cabeça", "cabecas": "cabeças",
        "forca": "força", "forcas": "forças",
        "diferenca": "diferença", "diferencas": "diferenças",
        "presenca": "presença",
        "ausencia": "ausência",
        "influencia": "influência",
        "violencia": "violência",
        "experiencia": "experiência",
        "ciencia": "ciência", "ciencias": "ciências",
        "consciencia": "consciência",
        "paciencia": "paciência",
        "agencia": "agência",
        "emergencia": "emergência",
        "frequencia": "frequência",
        "tendencia": "tendência",
        "preferencia": "preferência",
        "referencia": "referência",
        "consequencia": "consequência",
        "comeco": "começo",
        "almoco": "almoço",
        "poco": "poço",
        "troco": "troco",  // change (money)
        "pedaco": "pedaço", "pedacos": "pedaços",
        "abraco": "abraço", "abracos": "abraços",
        "caca": "caça",
        "raca": "raça", "racas": "raças",
        "ameaca": "ameaça",
        "certidao": "certidão",
        "crianca": "criança", "criancas": "crianças",
        "licenca": "licença",
        "lembranca": "lembrança",
        "esperanca": "esperança",
        "confianca": "confiança",
        "seguranca": "segurança",
        "mudanca": "mudança",
        "alianca": "aliança",
        "balanca": "balança",
        "vizinhanca": "vizinhança",
        "heranca": "herança",
        "semelhanca": "semelhança",

        // ==========================================
        // CIRCUMFLEX ACCENT (^) - ê, ô, â
        // ==========================================

        // Words with ê
        "ele": "ele",  // no accent usually
        "tres": "três",
        "mes": "mês", "meses": "meses",
        "pes": "pés",  // feet
        "voce": "você", "voces": "vocês",
        "sede": "sede",  // thirst (no accent) vs headquarters
        "portugues": "português",
        "ingles": "inglês",
        "frances": "francês",
        "holandes": "holandês",
        "interesse": "interesse",
        "frequente": "frequente",

        // Words with ô
        "nos": "nós",  // we (context dependent)
        "vos": "vós",  // you (archaic)
        "po": "pó",  // dust
        "avos": "avôs",  // grandfathers
        "onibus": "ônibus",
        "bonus": "bônus",
        "tonico": "tônico",
        "cronico": "crônico",
        "eletronico": "eletrônico",
        "economico": "econômico",
        "astronomico": "astronômico",
        "gastronomico": "gastronômico",

        // Words with â
        "ambar": "âmbar",
        "ancora": "âncora",
        "angulo": "ângulo",
        "animo": "ânimo",
        "ambito": "âmbito",

        // ==========================================
        // COMMON WORDS AND PHRASES
        // ==========================================

        // Question words
        "porque": "porquê",  // why (as noun/answer)
        "por que": "por que",  // why (in questions - no change but for completeness)

        // Common adverbs and conjunctions
        "so": "só",
        "alias": "aliás",
        "atras": "atrás",
        "atraves": "através",
        "apos": "após",
        "porem": "porém",
        "todavia": "todavia",
        "contudo": "contudo",
        "entretanto": "entretanto",
        "portanto": "portanto",
        "assim": "assim",

        // Time expressions
        "sabado": "sábado",
        "domingo": "domingo",
        "segunda-feira": "segunda-feira",
        "terca-feira": "terça-feira",
        "quarta-feira": "quarta-feira",
        "quinta-feira": "quinta-feira",
        "sexta-feira": "sexta-feira",

        // Months (most don't have accents in Portuguese)
        "marco": "março",

        // Common verbs (various tenses)
        "faco": "faço",
        "digo": "digo",
        "traco": "traço",
        "conheco": "conheço",
        "apareco": "apareço",
        "esqueco": "esqueço",
        "ofereco": "ofereço",
        "pareco": "pareço",
        "perteco": "pertenço",
        "agradeco": "agradeço",
        "aconteco": "aconteço",
        "desapareco": "desapareço",
        "reconheco": "reconheço",

        // Imperative/subjunctive forms
        "faca": "faça",
        "diga": "diga",
        "vaca": "vá",  // careful - vaca = cow, but context helps
        "traga": "traga",
        "conheca": "conheça",
        "apareca": "apareça",
        "esqueca": "esqueça",
        "ofereca": "ofereça",
        "pareca": "pareça",
        "pertenca": "pertença",
        "agradeca": "agradeça",

        // Common nouns
        "pais": "país", "paises": "países",
        "portugues": "português",
        "frances": "francês",
        "ingles": "inglês",
        "japones": "japonês",
        "chines": "chinês",
        "obrigado": "obrigado",  // no accent
        "obrigada": "obrigada",  // no accent
        "familia": "família",
        "historia": "história",
        "memoria": "memória",
        "vitoria": "vitória",
        "categoria": "categoria",
        "estrategia": "estratégia",
        "energia": "energia",
        "tecnologia": "tecnologia",
        "ideologia": "ideologia",
        "psicologia": "psicologia",
        "filosofia": "filosofia",
        "biologia": "biologia",
        "sociologia": "sociologia",
        "metodologia": "metodologia",
        "economia": "economia",
        "democracia": "democracia",

        // ==========================================
        // INFORMAL/MESSAGING CORRECTIONS
        // ==========================================

        "vc": "você",
        "tb": "também",
        "tbm": "também",
        "pq": "porque",
        "q": "que",
        "n": "não",
        "qdo": "quando",
        "cmg": "comigo",
        "ctg": "contigo",
        "blz": "beleza",
        "vlw": "valeu",
        "obg": "obrigado",
        "flw": "falou",
        "msg": "mensagem",
    ]

    // MARK: - Portuguese Proper Nouns
    // Cities, regions, and other proper nouns requiring capitalization

    private static let portugueseProperNouns: [String: String] = [
        // Brazil - Major cities
        "brasil": "Brasil",
        "sao paulo": "São Paulo",
        "rio de janeiro": "Rio de Janeiro",
        "brasilia": "Brasília",
        "salvador": "Salvador",
        "fortaleza": "Fortaleza",
        "belo horizonte": "Belo Horizonte",
        "manaus": "Manaus",
        "curitiba": "Curitiba",
        "recife": "Recife",
        "goiania": "Goiânia",
        "belem": "Belém",
        "porto alegre": "Porto Alegre",
        "guarulhos": "Guarulhos",
        "campinas": "Campinas",
        "sao luis": "São Luís",
        "sao goncalo": "São Gonçalo",
        "maceio": "Maceió",
        "duque de caxias": "Duque de Caxias",
        "natal": "Natal",
        "teresina": "Teresina",
        "campo grande": "Campo Grande",
        "sao bernardo do campo": "São Bernardo do Campo",
        "joao pessoa": "João Pessoa",
        "osasco": "Osasco",
        "santo andre": "Santo André",
        "ribeirao preto": "Ribeirão Preto",
        "uberlandia": "Uberlândia",
        "sorocaba": "Sorocaba",
        "cuiaba": "Cuiabá",
        "florianopolis": "Florianópolis",
        "vitoria": "Vitória",
        "niteroi": "Niterói",
        "joinville": "Joinville",
        "londrina": "Londrina",
        "santos": "Santos",
        "aparecida de goiania": "Aparecida de Goiânia",
        "juiz de fora": "Juiz de Fora",
        "aracaju": "Aracaju",
        "feira de santana": "Feira de Santana",
        "serra": "Serra",
        "vila velha": "Vila Velha",
        "diadema": "Diadema",
        "campina grande": "Campina Grande",
        "caxias do sul": "Caxias do Sul",
        "maua": "Mauá",
        "sao jose dos campos": "São José dos Campos",
        "sao jose do rio preto": "São José do Rio Preto",
        "piracicaba": "Piracicaba",
        "mogi das cruzes": "Mogi das Cruzes",
        "bauru": "Bauru",
        "maringa": "Maringá",
        "jundiai": "Jundiaí",
        "anapolis": "Anápolis",
        "petropolis": "Petrópolis",
        "paranagua": "Paranaguá",
        "foz do iguacu": "Foz do Iguaçu",
        "gramado": "Gramado",
        "paraty": "Paraty",
        "buzios": "Búzios",
        "ouro preto": "Ouro Preto",
        "tiradentes": "Tiradentes",
        "angra dos reis": "Angra dos Reis",
        "ilhabela": "Ilhabela",

        // Brazil - States
        "acre": "Acre",
        "alagoas": "Alagoas",
        "amapa": "Amapá",
        "amazonas": "Amazonas",
        "bahia": "Bahia",
        "ceara": "Ceará",
        "espirito santo": "Espírito Santo",
        "goias": "Goiás",
        "maranhao": "Maranhão",
        "mato grosso": "Mato Grosso",
        "mato grosso do sul": "Mato Grosso do Sul",
        "minas gerais": "Minas Gerais",
        "para": "Pará",
        "paraiba": "Paraíba",
        "parana": "Paraná",
        "pernambuco": "Pernambuco",
        "piaui": "Piauí",
        "rio grande do norte": "Rio Grande do Norte",
        "rio grande do sul": "Rio Grande do Sul",
        "rondonia": "Rondônia",
        "roraima": "Roraima",
        "santa catarina": "Santa Catarina",
        "sao paulo estado": "São Paulo",
        "sergipe": "Sergipe",
        "tocantins": "Tocantins",

        // Portugal - Major cities
        "portugal": "Portugal",
        "lisboa": "Lisboa",
        "porto": "Porto",
        "coimbra": "Coimbra",
        "braga": "Braga",
        "amadora": "Amadora",
        "funchal": "Funchal",
        "setubal": "Setúbal",
        "almada": "Almada",
        "aveiro": "Aveiro",
        "evora": "Évora",
        "faro": "Faro",
        "guimaraes": "Guimarães",
        "leiria": "Leiria",
        "viseu": "Viseu",
        "viana do castelo": "Viana do Castelo",
        "braganca": "Bragança",
        "castelo branco": "Castelo Branco",
        "guarda": "Guarda",
        "portalegre": "Portalegre",
        "santarem": "Santarém",
        "beja": "Beja",
        "sintra": "Sintra",
        "cascais": "Cascais",
        "estoril": "Estoril",
        "obidos": "Óbidos",
        "tomar": "Tomar",
        "batalha": "Batalha",
        "alcobaca": "Alcobaça",
        "nazare": "Nazaré",

        // Portugal - Regions
        "algarve": "Algarve",
        "alentejo": "Alentejo",
        "madeira": "Madeira",
        "acores": "Açores",
        "minho": "Minho",
        "douro": "Douro",
        "beira": "Beira",
        "estremadura": "Estremadura",
        "ribatejo": "Ribatejo",

        // Other Portuguese-speaking countries/cities
        "angola": "Angola",
        "luanda": "Luanda",
        "mocambique": "Moçambique",
        "maputo": "Maputo",
        "cabo verde": "Cabo Verde",
        "praia": "Praia",
        "guine-bissau": "Guiné-Bissau",
        "bissau": "Bissau",
        "sao tome e principe": "São Tomé e Príncipe",
        "timor-leste": "Timor-Leste",
        "dili": "Dili",
        "macau": "Macau",
        "goa": "Goa",

        // Countries (common in Portuguese)
        "estados unidos": "Estados Unidos",
        "espanha": "Espanha",
        "franca": "França",
        "alemanha": "Alemanha",
        "italia": "Itália",
        "inglaterra": "Inglaterra",
        "reino unido": "Reino Unido",
        "holanda": "Holanda",
        "paises baixos": "Países Baixos",
        "belgica": "Bélgica",
        "suica": "Suíça",
        "austria": "Áustria",
        "grecia": "Grécia",
        "russia": "Rússia",
        "china": "China",
        "japao": "Japão",
        "india": "Índia",
        "mexico": "México",
        "argentina": "Argentina",
        "chile": "Chile",
        "colombia": "Colômbia",
        "peru": "Peru",
        "venezuela": "Venezuela",
        "paraguai": "Paraguai",
        "uruguai": "Uruguai",
        "equador": "Equador",
        "bolivia": "Bolívia",
        "africa do sul": "África do Sul",
        "egito": "Egito",
        "marrocos": "Marrocos",
        "australia": "Austrália",
        "nova zelandia": "Nova Zelândia",
        "canada": "Canadá",

        // Geographic features
        "rio amazonas": "Rio Amazonas",
        "rio sao francisco": "Rio São Francisco",
        "rio parana": "Rio Paraná",
        "rio tejo": "Rio Tejo",
        "rio douro": "Rio Douro",
        "oceano atlantico": "Oceano Atlântico",
        "serra da estrela": "Serra da Estrela",
        "chapada diamantina": "Chapada Diamantina",
        "pantanal": "Pantanal",
        "amazonia": "Amazônia",
        "mata atlantica": "Mata Atlântica",
        "cataratas do iguacu": "Cataratas do Iguaçu",
        "pao de acucar": "Pão de Açúcar",
        "corcovado": "Corcovado",
        "copacabana": "Copacabana",
        "ipanema": "Ipanema",
        "leblon": "Leblon",

        // Important places
        "cristo redentor": "Cristo Redentor",
        "maracana": "Maracanã",
        "torre de belem": "Torre de Belém",
        "mosteiro dos jeronimos": "Mosteiro dos Jerónimos",
        "palacio da pena": "Palácio da Pena",
        "universidade de coimbra": "Universidade de Coimbra",
        "usp": "USP",
        "unicamp": "Unicamp",
        "ufrj": "UFRJ",
    ]

    // MARK: - Portuguese Abbreviations

    /// Common Portuguese abbreviations
    static let portugueseAbbreviations: Set<String> = [
        // Titles
        "sr.", "sra.", "srta.", "dr.", "dra.", "prof.", "profa.",
        "eng.", "arq.", "adv.",

        // Common abbreviations
        "etc.", "obs.", "ex.", "pág.", "págs.", "cap.", "vol.",
        "tel.", "cel.", "fax.", "e-mail",
        "n°", "nº", "av.", "r.", "al.", "pç.", "trav.",

        // Units and measurements
        "km", "m", "cm", "mm", "kg", "g", "mg", "l", "ml",
        "min.", "seg.", "h", "hs.",

        // Common shortened forms
        "aprox.", "ref.", "qt.", "qtd.", "qts.",
        "c/", "s/", "p/", "a/c",

        // Days and months
        "seg.", "ter.", "qua.", "qui.", "sex.", "sáb.", "dom.",
        "jan.", "fev.", "mar.", "abr.", "mai.", "jun.",
        "jul.", "ago.", "set.", "out.", "nov.", "dez.",

        // Legal and business
        "ltda.", "s/a", "cia.", "inc.",
        "art.", "§", "inc.", "al.",

        // Geographic
        "est.", "mun.", "dist.",
    ]
}
