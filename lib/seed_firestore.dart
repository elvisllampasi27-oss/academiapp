// Ejecuta esto UNA SOLA VEZ desde un botón temporal en tu app
// o desde la consola de Firebase con JS equivalente.
// Pégalo en main.dart temporalmente y llámalo en initState o un botón.

import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedCursos() async {
  final db = FirebaseFirestore.instance;

  final cursos = [
    // ==================== 1. COMUNICACIÓN ====================
    {
      'id': 'razonamiento_verbal',
      'nombre': 'Razonamiento Verbal',
      'area': 'Comunicación',
      'orden': 1,
      'icono': '📖',
      'temas': [
        'Etimología: sufijos y étimos',
        'Morfología: morfema lexical, derivativo (prefijo, sufijo) y flexivo',
        'Conectores lógicos y referencias textuales (anáfora, catáfora, elipsis)',
        'Oraciones incompletas',
        'Oraciones eliminadas',
        'Plan de redacción',
        'Comprensión lectora: niveles literal, inferencial y crítico. Estructura textual',
        'Parónimos y homónimos: homófonos, homógrafos, parónimos',
        'Sinonimia: sinónimos contextuales, relación de significado',
        'Antonimia: antónimos directos e indirectos, prefijos de negación',
        'Series verbales, términos excluidos y analogías',
        'Analogías',
      ],
    },
    {
      'id': 'lenguaje',
      'nombre': 'Lenguaje',
      'area': 'Comunicación',
      'orden': 2,
      'icono': '✍️',
      'temas': [
        'Signo lingüístico y elementos de la comunicación',
        'Lengua, habla y funciones del lenguaje',
        'Formación y evolución del castellano (lenguas prerromanas, latín, lenguas romances)',
        'Uso de mayúsculas y minúsculas',
        'Ortografía de la sílaba y tildación general',
        'Morfología y categorías gramaticales',
        'El adjetivo, artículo, los determinantes y pronombre',
        'El verbo, verboides, adverbio, preposición y conjunción',
        'La oración gramatical: clasificación semántica y sintáctica, sujeto y predicado, estructura y clases',
        'El predicado',
        'Signos de puntuación',
        'Vicios de lenguaje y redacción administrativa',
      ],
    },
    {
      'id': 'literatura',
      'nombre': 'Literatura',
      'area': 'Comunicación',
      'orden': 3,
      'icono': '📚',
      'temas': [
        'Géneros literarios, figuras literarias y disciplinas literarias',
        'Clasicismo: "La Odisea" (Homero), Medievalismo: "La Divina Comedia" (Dante Alighieri), Renacimiento: "Romeo y Julieta" (Shakespeare)',
        'Romanticismo: "Nuestra Señora de París" (Víctor Hugo)',
        'Realismo: "Papá Goriot" (Balzac) y Vanguardismo: "La metamorfosis" (Kafka)',
        'Medievalismo español: "El Cantar de Mío Cid" y Siglo de Oro: "El ingenioso hidalgo Don Quijote de la Mancha" (Cervantes)',
        'Romanticismo español: "Rimas LIII" (Bécquer), Generación del 98: "Campos de Castilla" (Antonio Machado), Generación del 27: "La casada infiel" (García Lorca) y "La familia de Pascual Duarte" (Camilo José Cela)',
        'Literatura hispanoamericana: Modernismo (Rubén Darío, "Prosas profanas", "Sonatina"), Vanguardismo (Pablo Neruda, "Veinte poemas de amor...", Jorge Luis Borges, "La casa de Asterión")',
        'Realismo mágico y Boom Latinoamericano: Juan Rulfo ("Pedro Páramo"), Gabriel García Márquez ("Cien años de soledad")',
        'Literatura peruana: periodización (Literatura Inca, Conquista, Colonia, República), Romanticismo (Ricardo Palma, "Tradiciones peruanas", "Don Dimas de la Tijereta")',
        'Realismo e Indigenismo peruano: Clorinda Matto de Turner ("Aves sin nido"), José Santos Chocano ("Alma América", "Blasón")',
        'Vanguardismo y Movimiento Colónida: Abraham Valdelomar ("El caballero Carmelo"), César Vallejo ("Trilce", "Masa"), Indigenismo (José María Arguedas, "Los ríos profundos")',
        'Narrativa urbana y literatura ayacuchana: Julio Ramón Ribeyro ("Al pie del acantilado"), Mario Vargas Llosa ("La ciudad y los perros"), autores ayacuchanos (Hildebrando Pérez Huarancca, Marcial Molina Richter, Sócrates Zuzunaga Huayta, Daniel Quispe Torres)',
      ],
    },

    // ==================== 2. MATEMÁTICA ====================
    {
      'id': 'aritmetica',
      'nombre': 'Aritmética',
      'area': 'Matemática',
      'orden': 4,
      'icono': '🔢',
      'temas': [
        'Razones y proporciones',
        'Magnitudes proporcionales',
        'Regla de tres',
        'Regla del tanto por ciento',
        'Promedios',
        'Conjuntos I',
        'Operaciones entre conjuntos',
        'Numeración',
        'Divisibilidad y multiplicidad',
        'Números primos',
        'MCD y MCM',
        'Números racionales, potenciación y radicación',
      ],
    },
    {
      'id': 'algebra',
      'nombre': 'Álgebra',
      'area': 'Matemática',
      'orden': 5,
      'icono': '🔣',
      'temas': [
        'Teoría de exponentes y ecuaciones exponenciales',
        'Polinomios',
        'Productos notables',
        'División entera de polinomios y métodos de división',
        'Divisibilidad y cocientes notables',
        'Factorización en Q',
        'Ecuaciones de primer grado y segundo grado',
        'Sistemas de ecuaciones lineales',
        'Ecuación bicuadrada e inecuaciones',
        'Valor absoluto y funciones',
        'Funciones especiales: lineal, raíz cuadrada, etc.',
        'Funciones exponencial y logarítmica, valor absoluto, inyectiva, biyectiva, etc.',
      ],
    },
    {
      'id': 'geometria',
      'nombre': 'Geometría',
      'area': 'Matemática',
      'orden': 6,
      'icono': '📐',
      'temas': [
        'Ángulos',
        'Triángulos rectilíneos',
        'Líneas notables en triángulos: mediana, altura, bisectriz, incentro, baricentro',
        'Congruencia de triángulos',
        'Cuadriláteros convexos',
        'Circunferencia: propiedades de tangentes, cuerdas, ángulos inscritos y centrales',
        'Circunferencia y ángulos: teoremas de la circunferencia, cuadriláteros inscriptibles',
        'Proporcionalidad y semejanza: teorema de Thales, teoremas de la bisectriz, semejanza de triángulos',
        'Relaciones métricas en la circunferencia: teorema de las cuerdas, secantes y tangente',
        'Áreas de regiones poligonales y circulares',
        'Geometría analítica I: punto medio, distancia entre dos puntos, baricentro',
        'Geometría analítica II: ecuación de la recta, ecuación de la circunferencia',
      ],
    },
    {
      'id': 'trigonometria',
      'nombre': 'Trigonometría',
      'area': 'Matemática',
      'orden': 7,
      'icono': '📏',
      'temas': [
        'Sistemas de medición angular: sexagesimal, centesimal y radial, conversión',
        'Área de un sector circular: longitud de arco, área de sector circular',
        'Razones trigonométricas de un ángulo agudo: definición en triángulos rectángulos',
        'Ángulo de elevación y depresión: problemas con ángulos, direcciones (N, S, E, O)',
        'Ángulos en posición normal: signo de las razones, reducción al primer cuadrante',
        'Circunferencia trigonométrica: variación de razones, cálculo de áreas',
        'Identidades trigonométricas: fundamentales y auxiliares, simplificación',
        'Ángulos compuestos: suma y diferencia de ángulos, identidades adicionales',
        'Reducción al primer cuadrante: ángulos negativos y mayores a 360°',
        'Ángulos múltiples: ángulo doble, triple y mitad',
        'Transformaciones trigonométricas: suma a producto, producto a suma',
        'Resolución de triángulos oblicuángulos, ecuaciones trigonométricas',
      ],
    },

    // ==================== 3. CIENCIAS Y TECNOLOGÍA ====================
    {
      'id': 'quimica',
      'nombre': 'Química',
      'area': 'Ciencias y Tecnología',
      'orden': 8,
      'icono': '🧪',
      'temas': [
        'La materia: clasificación, estados de agregación, fenómenos físicos y químicos, propiedades',
        'Estructura atómica: Z, A, isótopos, isóbaros, isótonos, iones, distribución electrónica, números cuánticos',
        'Tabla periódica y enlace químico: configuración electrónica, regla del octeto, tipos de enlace',
        'Nomenclatura inorgánica: funciones químicas, sistemas de nomenclatura, formulación',
        'Reacciones y ecuaciones químicas: clasificación de reacciones, balanceo de ecuaciones',
        'Cálculos químicos y estado gaseoso: mol, número de Avogadro, leyes de los gases, ecuación general',
        'Estequiometría y soluciones: leyes ponderales, reactivo limitante, concentración de soluciones',
        'Ácidos, bases y química nuclear: pH, pOH, neutralización, radiactividad, reacciones nucleares',
        'Química ambiental: contaminación del aire, agua y suelo, ciclos biogeoquímicos',
        'Química orgánica I: propiedades del carbono, hidrocarburos, nomenclatura',
        'Funciones químicas inorgánicas',
        'Reacciones y ecuaciones químicas',
      ],
    },
    {
      'id': 'biologia',
      'nombre': 'Biología',
      'area': 'Ciencias y Tecnología',
      'orden': 9,
      'icono': '🧬',
      'temas': [
        'La biología y niveles de organización',
        'Biomoléculas orgánicas: glúcidos, lípidos, proteínas, ácidos nucleicos',
        'Citología: teoría celular, clasificación de células, estructura celular, transporte de membrana',
        'Función de nutrición I: tipos de nutrición, digestión, sistemas digestivos, respiración',
        'Función de nutrición II: circulación, transporte, excreción',
        'Metabolismo celular: fotosíntesis, respiración celular',
        'Ciclo celular eucariota: interfase, mitosis, meiosis',
        'Función de relación y coordinación: estímulo, receptor, centro de coordinación, efector, fitohormonas, sistema nervioso en invertebrados y vertebrados',
        'Reproducción humana y desarrollo embrionario: gametogénesis, ciclo menstrual, fecundación, desarrollo embrionario, reproducción vegetativa',
        'Genética y biotecnología: conceptos básicos, leyes de Mendel, herencia ligada al sexo, anomalías cromosómicas, mutaciones, técnicas biotecnológicas',
        'Origen de la vida y evolución: teorías, evolucionismo, adaptaciones, especiación, fósiles',
        'Ecología: ecosistema, niveles tróficos, relaciones ecológicas, recursos naturales, cambio climático, biodiversidad',
      ],
    },
    {
      'id': 'fisica',
      'nombre': 'Física',
      'area': 'Ciencias y Tecnología',
      'orden': 10,
      'icono': '⚛️',
      'temas': [
        'Magnitudes y ecuaciones dimensionales: clasificación, principio de homogeneidad',
        'Análisis vectorial: operaciones con vectores, métodos de suma, componentes rectangulares',
        'Cinemática I: MRU, MRUV, gráficas de movimiento',
        'Cinemática II: MVCL, movimiento parabólico, MCU, transmisión de movimiento circular',
        'Estática y momento de fuerza: equilibrio de cuerpos, fuerzas usuales',
        'Dinámica lineal y circular: segunda ley de Newton, fuerza de rozamiento, fuerza centrípeta',
        'Trabajo y potencia: trabajo mecánico, potencia, eficiencia',
        'Oscilaciones y ondas',
        'Hidrostática',
        'Electrostática',
        'Electrodinámica',
        'Electromagnetismo',
      ],
    },
    {
      'id': 'anatomia',
      'nombre': 'Anatomía Humana',
      'area': 'Ciencias y Tecnología',
      'orden': 11,
      'icono': '🫀',
      'temas': [
        'Sistema cardiovascular: componentes y anatomía del corazón',
        'Sistema nodal, ciclo cardíaco y gasto cardíaco',
        'Sistema respiratorio: vías respiratorias, pulmones, hematosis, transporte de gases',
        'Sistema digestivo humano I: tubo digestivo, glándulas anexas, histología, boca, esófago, estómago',
        'Sistema digestivo humano II: intestino delgado, intestino grueso, glándulas anexas',
        'Sistema urinario: riñones, vías urinarias, nefrón, formación de la orina',
        'Regulación renal: sistema Renina-Angiotensina-Aldosterona, homeostasis',
        'Sistema nervioso central: encéfalo, médula espinal, meninges, neuronas, actos reflejos',
        'Sistema nervioso periférico y autónomo: nervios craneales y raquídeos, simpático y parasimpático',
        'Sistema endocrino: glándulas endocrinas, hormonas, mecanismo de retroalimentación',
        'Sistema inmunológico: órganos linfoides, células de defensa, anticuerpos, tipos de inmunidad',
        'Sistema reproductor masculino y femenino',
        'Sistema sensorial: receptores sensoriales, gusto, olfato, vista, audición y equilibrio',
      ],
    },

    // ==================== 4. CIENCIAS SOCIALES ====================
    {
      'id': 'historia_peru',
      'nombre': 'Historia del Perú',
      'area': 'Ciencias Sociales',
      'orden': 12,
      'icono': '🏛️',
      'temas': [
        'Historia del Perú: concepto, fuentes y ciencias auxiliares. Teorías del poblamiento americano',
        'El Primer Horizonte: Cultura Chavín, Vicus, culturas Puente (formativo superior) y Cultura Moche, Nazca y Tiahuanaco (intermedio temprano)',
        'Horizonte Medio: cultura Wari, intermedio tardío: cultura Chimú, Chanca y Chincha',
        'Horizonte Tardío: Los Incas',
        'Contexto Europeo, Descubrimiento y Primeros Viajes',
        'Conquista, guerras civiles y resistencia andina',
        'Virreinato en el Perú',
        'La emancipación: Rebeliones indígenas, corrientes libertadoras',
        'La república peruana: Primer Militarismo',
        'El segundo militarismo (reconstrucción nacional) y República Aristocrática (Elitista)',
        'El Oncenio de Augusto B. Leguía y Gobierno de las fuerzas armadas',
        'El Civilismo democrático',
      ],
    },
    {
      'id': 'historia_universal',
      'nombre': 'Historia Universal',
      'area': 'Ciencias Sociales',
      'orden': 13,
      'icono': '🌎',
      'temas': [
        'Historia: concepto y periodificación',
        'Cultura Caldeo-Asiria, Egipto',
        'Cultura Fenicia, Persia, India y China',
        'Grecia, Esparta, Atenas, Las Guerras Médicas',
        'Roma',
        'Edad Media o Feudal: imperio Carolingio y feudalismo',
        'Las cruzadas, imperio Bizantino, humanismo y Renacimiento',
        'Edad Moderna: la reforma protestante, contrarreforma, la ilustración, el despotismo ilustrado',
        'Edad contemporánea: revolución francesa, revolución industrial, socialismo y capitalismo',
        'Primera guerra mundial, revolución rusa, fascismo, nazismo',
        'Segunda guerra mundial',
        'La guerra fría',
      ],
    },
    {
      'id': 'economia',
      'nombre': 'Economía',
      'area': 'Ciencias Sociales',
      'orden': 14,
      'icono': '📊',
      'temas': [
        'Economía: definición, métodos de estudio (inductivo, deductivo), división de la economía (microeconomía, macroeconomía)',
        'Necesidades y bienes: clasificación de necesidades, leyes de la necesidad, clasificación de bienes (económicos, no económicos, bienes de capital)',
        'Actividades económicas: factores de la producción, retribución a los factores, proceso económico (producción, circulación, distribución, consumo)',
        'El Trabajo, El capital',
        'Teoría de la producción: productividad, función de producción, costos de producción (fijos, variables, marginales, a corto y largo plazo)',
        'Oferta y demanda: ley de la demanda, factores determinantes, desplazamiento de la curva, ley de la oferta, precio de equilibrio',
        'Macroeconomía y sistema financiero: Bolsa de Valores de Lima (BVL), Banco Central de Reserva del Perú (BCRP)',
        'La inflación',
        'Presupuesto público: ingresos (tributarios y no tributarios), gastos (corrientes y de capital), déficit fiscal, superávit fiscal',
        'Teoría de los agregados económicos: PBI (nominal y real, métodos de cálculo), PNB, PNN, ingreso nacional (YN), ingreso personal (YP), ingreso disponible (YD), PBI per cápita',
        'El comercio internacional: cuenta corriente, cuenta financiera',
        'Globalización económica y las integraciones',
      ],
    },
    {
      'id': 'geografia',
      'nombre': 'Geografía',
      'area': 'Ciencias Sociales',
      'orden': 15,
      'icono': '🌍',
      'temas': [
        'Geografía: principios, evolución, espacio geográfico, gestión de riesgos de desastres',
        'Cartografía: líneas geodésicas, coordenadas geográficas, elementos de un mapa (proyección, escala)',
        'Geodinámica terrestre: estructura de la geósfera, meteorización y erosión',
        'Relieve geográfico: regiones naturales (costa, sierra, selva), formas de relieve',
        'Clima y regiones naturales: elementos del clima (temperatura, presión, vientos), las ocho regiones naturales del Perú (Chala, Yunga, Quechua, Suni, Puna, Janca, Rupa Rupa, Omagua)',
        'Hidrografía: océanos, mares, vertientes hidrográficas del Perú (Pacífico, Atlántico o Amazonas, Titicaca), ríos, cuencas y ciclo del agua',
        'Actividades económicas extractivas, actividades económicas productivas',
        'Población peruana: censos (INEI), indicadores demográficos, características de la población',
        'Atmósfera y cambio climático: composición, estructura, efecto invernadero, contaminación del aire, Estándares de Calidad Ambiental (ECA)',
        'Recursos naturales: niveles de diversidad, ecorregiones peruanas, áreas naturales protegidas (SINANPE, SERNANP)',
        'Fenómenos y desastres naturales',
        'Biodiversidad',
      ],
    },

    // ==================== 5. DPCC ====================
    {
      'id': 'formacion_civica',
      'nombre': 'Formación Cívica',
      'area': 'Desarrollo Personal, Ciudadanía y Cívica',
      'orden': 16,
      'icono': '⚖️',
      'temas': [
        'Persona natural y jurídica: capacidad de goce y ejercicio, incapacidad absoluta y restringida',
        'La familia: tipos de familia, funciones, paternidad responsable, planificación familiar, parentesco',
        'Matrimonio y uniones: régimen patrimonial, impedimentos, separación de cuerpos y divorcio',
        'Patria potestad, tutela y curatela: deberes de los padres, suspensión y extinción de la patria potestad, funciones del tutor y del curador',
        'Sucesiones y ciudadanía: tipos de sucesores, órdenes hereditarios, testamento, legítima, albacea, concepto de ciudadanía y derechos políticos',
        'Normas y constitución: la norma jurídica, estructura del ordenamiento jurídico, historia del constitucionalismo peruano, evolución de las constituciones en el Perú',
        'La ley y los derechos humanos: características de la ley, procedimiento legislativo, clasificación generacional de los derechos humanos, declaraciones internacionales',
        'Garantías constitucionales: procesos constitucionales y El Estado peruano',
        'Los poderes del Estado: Poder Legislativo (Congreso de la República), Poder Ejecutivo (presidente de la República, Consejo de ministros), Poder Judicial (estructura, principios)',
        'Órganos constitucionales autónomos: Contraloría, BCRP, SBS, JNJ, Ministerio Público, Defensoría del Pueblo, TC, JNE, ONPE, RENIEC',
        'Descentralización, estructura municipal, gobierno regional',
        'Funciones del régimen democrático, símbolos patrios y organismos internacionales',
      ],
    },

    // ==================== 6. RAZONAMIENTO MATEMÁTICO ====================
    {
      'id': 'razonamiento_matematico',
      'nombre': 'Razonamiento Matemático',
      'area': 'Razonamiento Matemático',
      'orden': 17,
      'icono': '🧩',
      'temas': [
        'Planteo de ecuaciones',
        'Edades',
        'Lógica recreativa, relaciones de tiempo y parentesco',
        'Cuatro operaciones, poleas y engranajes',
        'Sucesiones, series, sumatorias, analogías y distribuciones',
        'Inducción, deducción, cortes, estacas y pastillas',
        'Operadores matemáticos y binarios',
        'Análisis combinatorio',
        'Probabilidades',
        'Estadística',
        'Lógica proposicional I',
        'Lógica proposicional II y orden de información',
      ],
    },
  ];

  for (final curso in cursos) {
    final temas = curso['temas'] as List<String>;
    final cursoId = curso['id'] as String;

    // Verificar si ya existe para evitar duplicados
    final existing = await db.collection('cursos').doc(cursoId).get();
    if (existing.exists) {
      print('⚠️ Curso ${curso['nombre']} ya existe, saltando...');
      continue;
    }

    // Crear documento del curso
    await db.collection('cursos').doc(cursoId).set({
      'nombre': curso['nombre'],
      'area': curso['area'],
      'orden': curso['orden'],
      'icono': curso['icono'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Crear temas de ese curso
    for (int i = 0; i < temas.length; i++) {
      await db.collection('cursos').doc(cursoId).collection('temas').add({
        'titulo': temas[i],
        'orden': i + 1,
        'videoId': '',
        'pdfUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    print('✅ Curso cargado: ${curso['nombre']} (${temas.length} temas)');
  }

  print('🎉 Todos los cursos cargados en Firestore');
}
