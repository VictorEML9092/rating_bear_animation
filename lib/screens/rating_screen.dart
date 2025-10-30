import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle; // Nuevo: para leer archivos de assets en memoria
import 'package:rive/rive.dart'; // Necesario para usar la API "baja" de Rive (RiveFile, Artboard, etc.)

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});
  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  // NUEVO ENFOQUE: trabajamos con 2 artboards
  Artboard?
  _master; // "Molde" original cargado desde el .riv (NO se muestra nunca)
  Artboard?
  _current; // Copia activa/visible; se reemplaza para interrumpir animaciones

  // Inputs de la State Machine (triggers de Rive)
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;

  int _rating = 0;

  // ---- CARGA DEL ARCHIVO ----
  @override
  void initState() {
    super.initState();
    _loadRive(); // Nuevo: cargamos el .riv manualmente (ya no usamos RiveAnimation.asset)
  }

  Future<void> _loadRive() async {
    // MUY IMPORTANTE EN WEB/ESCRITORIO:
    // Inicializa el motor de Rive ANTES de importar archivos .riv
    await RiveFile.initialize();

    // Leemos el archivo .riv desde assets en memoria (bytes crudos)
    final bytes = await rootBundle.load('assets/animated_login_character.riv');

    // Importamos esos bytes a un RiveFile (parseo del formato .riv)
    final file = RiveFile.import(bytes.buffer.asByteData());

    // Obtenemos el artboard principal del archivo
    final main = file.mainArtboard;

    // Guardamos el artboard original como "molde" para clonar instancias limpias
    setState(() {
      _master = main;
    });

    // Creamos la primera instancia visible y conectamos la State Machine
    _rebuildArtboardAndAttachController();
  }

  // ---- RECONSTRUIR STATE MACHINE (INTERRUPCIÓN REAL) ----
  void _rebuildArtboardAndAttachController() {
    if (_master == null) return;

    // Clona el artboard original (_master) para empezar SIEMPRE desde estado limpio
    final fresh = _master!.instance();

    // Busca dentro del Artboard un State Machine con ese nombre
    // Si lo encuentra, crea un controlador que permite manejar los inputs
    // fres: es un Artboard recienc clonado del archivo .riv
    final ctrl = StateMachineController.fromArtboard(fresh, 'Login Machine');

    // Conectamos el controlador a la instancia "fresh"
    fresh.addController(ctrl!);

    // Obtenemos los inputs concretos de tipo Trigger por nombre exacto
    _trigSuccess = ctrl.findSMI<SMITrigger>('trigSuccess');
    _trigFail = ctrl.findSMI<SMITrigger>('trigFail');
    debugPrint('Inputs -> success: $_trigSuccess | fail: $_trigFail');

    // Hacemos visible esta nueva instancia en pantalla (interrumpe la anterior)
    setState(() => _current = fresh);
  }

  // ---- REINICIAR + DISPARAR TRIGGER ----
  Future<void> _restartAndFire({required bool happy}) async {
    // Creamos una nueva instancia limpia y re-adjuntamos la State Machine
    _rebuildArtboardAndAttachController();

    // Esperamos un frame para asegurar que el nuevo artboard ya se montó en el árbol
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ahora sí, disparamos el trigger correspondiente
      if (happy) {
        _trigSuccess?.fire();
        debugPrint('➡️ fire trigSuccess');
      } else {
        _trigFail?.fire();
        debugPrint('➡️ fire trigFail');
      }
    });
  }

  // Reinicia el artboard sin disparar ninguna animación
  Future<void> _restartWithoutAnimation() async {
    // Crea un nuevo artboard limpio (como los otros métodos)
    _rebuildArtboardAndAttachController();

    // Espera un frame para asegurarte de que se monte correctamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // No disparamos ningún trigger aquí, simplemente se queda en idle
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Centra verticalmente (mejor UX)
            children: [
              SizedBox(
                width: size.width,
                height: 200,
                // Mientras _current es null mostramos un loader (el .riv está cargando)
                child: _current == null
                    ? const Center(child: CircularProgressIndicator())
                    // Nuevo: usamos el widget Rive con un "artboard" ya construido por nosotros
                    : Rive(artboard: _current!, fit: BoxFit.contain),
              ),

              const SizedBox(height: 10),

              // UI de texto/estrellas (igual que antes)
              const Text(
                'Enjoying Sounter?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),

              const SizedBox(height: 8),

              const Text(
                'With how many stars do you rate your experience?\nTap a star to rate!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),

              const SizedBox(height: 10),

              // Estrellas: la lógica dispara _restartAndFire(...) para interrumpir y animar
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final index = i + 1;
                  final filled = _rating >= index;
                  return IconButton(
                    iconSize: 44,
                    color: filled ? Colors.amber : Colors.grey,
                    icon: Icon(filled ? Icons.star : Icons.star_border),
                    onPressed: () {
                      setState(() => _rating = index);

                      // Aquí decidimos qué trigger disparar
                      if (_rating >= 4) {
                        _restartAndFire(happy: true); // éxito/alegre
                      } else if (_rating <= 2) {
                        _restartAndFire(happy: false); // fallo/triste
                      } else {
                        _restartWithoutAnimation();
                      }
                    },
                  );
                }),
              ),

              const SizedBox(height: 10),

              // Botones extra de tu UI (sin relación con Rive)
              MaterialButton(
                minWidth: size.width,
                height: 50,
                color: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadiusGeometry.circular(12),
                ),
                onPressed: () {},
                child: const Text(
                  'Rate Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              MaterialButton(
                minWidth: size.width,
                height: 50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadiusGeometry.circular(12),
                ),
                onPressed: () {},
                child: const Text(
                  'NO THANKS',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
