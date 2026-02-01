# ROADMAP EXTENDIDO - APPTIMECONTROL

## FASE ACTUAL: MVP ALPHA COMPLETADO ✅

**Duración**: 6 sprints (6-8 semanas)
**Estado**: 100% completado + features del MVP Beta

**Entregables cumplidos**:
- ✅ Tracking preciso de uso de apps
- ✅ Bloqueo automático por cuota diaria
- ✅ Bloqueo contextual por WiFi
- ✅ Reset diario a medianoche
- ✅ UI minimalista funcional
- ✅ Modo administrador con PIN
- ✅ Notificaciones de cuota (Beta)
- ✅ Export/Import configuración (Beta)

---

## FASE 1: CORRECCIONES CRÍTICAS

**Objetivo**: Resolver problemas bloqueantes identificados por el usuario

### Sprint 11 — Detección Completa y Protección (1-2 semanas)

**Problemas a resolver**:
1. **Detección incompleta de apps instaladas**
   - Refactorizar filtro de apps del sistema
   - Incluir apps actualizadas del sistema
   - Mostrar apps de usuario + apps del sistema con actualizaciones
   - Excluir solo apps core de Android

2. **Detección automática de redes WiFi**
   - Implementar detección dinámica en Android 10+
   - Fallback a redes guardadas en versiones antiguas
   - Auto-agregar red actual al selector
   - Mantener histórico de redes bloqueadas

3. **Protección contra desinstalación**
   - Implementar DeviceAdminReceiver
   - Solicitar permisos de administrador de dispositivo
   - Bloquear desinstalación mientras admin activo
   - Mostrar advertencia al intentar desactivar

**Entregables**:
- Lista completa de apps detectadas
- Selector WiFi con red actual visible
- App imposible de desinstalar sin desactivar admin
- Tests en dispositivos Android 10, 11, 12, 13+

**Criterios de aceptación**:
- ✅ Mínimo 95% de apps de usuario detectadas
- ✅ Red WiFi actual siempre disponible en selector
- ✅ Requiere 2+ pasos para desinstalar app
- ✅ Sin crashes en ninguna versión Android soportada

---

### Sprint 12 — UI Material Design 3 (1-2 semanas)

**Objetivo**: Modernizar interfaz siguiendo guías oficiales de Android

**Mejoras visuales**:

1. **Tema Material Design 3**
   - Color scheme basado en Material You
   - Paleta dinámica (Android 12+)
   - Elevaciones y sombras correctas
   - Tipografía Material 3

2. **Cards y componentes**
   - Cards con bordes redondeados (16dp)
   - Ripple effects en interacciones
   - Estados visuales claros (pressed, focused, disabled)
   - Iconos Material Symbols (no Material Icons)

3. **Espaciado y padding**
   - Grid de 8dp consistente
   - Márgenes 16dp horizontal estándar
   - Separación entre elementos según guías
   - Áreas de toque mínimo 48x48dp

4. **Colores semánticos**
   - Surface variants correctos
   - On-surface para textos
   - Primary/Secondary/Tertiary bien diferenciados
   - Error/Warning/Success con contraste adecuado

5. **Animaciones sutiles**
   - Transiciones entre pantallas
   - Fade in/out de elementos
   - Micro-interacciones en botones
   - Progress indicators animados

**Pantallas a actualizar**:
- AppListScreen (pantalla principal)
- PermissionsScreen
- PinSetupScreen / PinVerifyScreen
- NotificationSettingsScreen
- ExportImportScreen
- Todos los diálogos (AppPicker, TimePicker, WifiPicker)

**Entregables**:
- Tema MD3 completo configurado
- Todas las pantallas actualizadas visualmente
- Animaciones suaves sin lag
- Tests visuales en diferentes tamaños de pantalla

**Criterios de aceptación**:
- ✅ Cumple Material Design 3 guidelines
- ✅ Contraste WCAG AA mínimo
- ✅ Responsive en tablets y teléfonos
- ✅ Sin inconsistencias visuales

---

## FASE 2: PERSISTENCIA Y CONFIABILIDAD

**Objetivo**: Asegurar que la configuración nunca se pierda y el sistema sea robusto

### Sprint 13 — Backup Automático y Recuperación (1 semana)

**Historia 1**: Backup automático local (3 SP)

**Como** usuario
**Quiero** que mis configuraciones se respalden automáticamente
**Para** no perder mi setup si algo falla

**Funcionalidades**:
- Export automático diario a almacenamiento interno
- Carpeta `/Android/data/com.example.timelock/backups/`
- Retención de últimos 7 backups
- Rotación automática (eliminar backups > 7 días)
- Backup manual adicional disponible

**Historia 2**: Restauración automática (2 SP)

**Como** usuario
**Quiero** que la app detecte backups previos al instalar
**Para** recuperar mi configuración automáticamente

**Funcionalidades**:
- Al abrir app: verificar si existen backups
- Mostrar diálogo si encuentra backup reciente
- Opción de restaurar o comenzar desde cero
- Preview de qué se restaurará (N apps, admin activo, etc)

**Historia 3**: Gestión de backups (2 SP)

**Pantalla de gestión**:
- Lista de backups disponibles con fecha/hora
- Tamaño de cada backup
- Vista previa de contenido
- Restaurar backup específico
- Eliminar backups manualmente
- Compartir backup (mismo export actual)

**Criterios de aceptación**:
- ✅ Backup automático cada medianoche
- ✅ Máximo 7 backups en disco
- ✅ Detección automática en primera apertura
- ✅ Restauración sin pérdida de datos

---

### Sprint 14 — Logs de Actividad (1 semana)

**Historia 1**: Registro de eventos (3 SP)

**Como** usuario
**Quiero** ver un historial de cuándo se bloquearon apps
**Para** entender mis patrones de uso

**Funcionalidades**:
- Nueva tabla `activity_logs` en base de datos
- Registrar eventos:
  - App bloqueada (con razón: cuota/wifi/horario)
  - App desbloqueada (medianoche/wifi desconectado)
  - Cuota modificada
  - Restricción agregada/eliminada
  - PIN cambiado
- Timestamp preciso de cada evento
- Retención últimos 30 días

**Historia 2**: Pantalla de historial (3 SP)

**Diseño**:
- Lista cronológica inversa (más reciente arriba)
- Filtros: última semana / último mes / hoy
- Agrupación por día
- Iconos distintivos por tipo de evento
- Búsqueda por nombre de app

**Formato de entradas**:
```
[Hoy 18:45] 🔒 Instagram bloqueada (cuota diaria alcanzada)
[Hoy 15:30] ⚙️ Cuota de TikTok cambiada: 30m → 20m
[Ayer 23:59] 🔓 Instagram desbloqueada (reset diario)
[Ayer 14:22] 🔒 YouTube bloqueada (WiFi: OfficeNetwork)
```

**Historia 3**: Export de logs (1 SP)

- Export a CSV para análisis externo
- Columnas: timestamp, app, evento, detalles
- Útil para revisar patrones sin estadísticas complejas

**Criterios de aceptación**:
- ✅ Todos los eventos importantes registrados
- ✅ Historial accesible y legible
- ✅ Sin impacto en rendimiento
- ✅ Purga automática de logs antiguos

---

### Sprint 15 — Modo Recuperación PIN (1 semana)

**Historia 1**: Recuperación segura (5 SP)

**Como** usuario que olvidó su PIN
**Quiero** poder recuperar acceso después de un período de espera
**Para** no quedar bloqueado permanentemente

**Flujo de recuperación**:

1. **Pantalla de PIN bloqueada**:
   - Tras 3 intentos fallidos: bloqueo 5 minutos (actual)
   - Tras 6 intentos fallidos totales: bloqueo 30 minutos
   - Tras 10 intentos fallidos: opción "Olvidé mi PIN"

2. **Proceso de reset**:
   - Botón "Olvidé mi PIN" solo aparece tras 10 intentos
   - Al tocar: inicia período de espera de 24 horas
   - Durante 24h: app funciona pero restricciones NO se pueden modificar
   - Notificación persistente con countdown
   - Al cumplir 24h: opción de crear nuevo PIN

3. **Pregunta de seguridad (opcional)**:
   - Al configurar PIN: opción de agregar pregunta
   - Ejemplos: "Nombre de tu primera mascota", "Ciudad de nacimiento"
   - Si configurada: reduce espera a 12 horas
   - Máximo 3 intentos de respuesta

4. **Email de recuperación (opcional, sin cloud)**:
   - Almacenar email local encriptado
   - Generar código de 6 dígitos aleatorio
   - Usuario debe copiar código y enviarlo a sí mismo
   - Código válido por 1 hora
   - Al ingresar código correcto: reset inmediato

**Criterios de aceptación**:
- ✅ Usuario nunca queda bloqueado permanentemente
- ✅ Proceso suficientemente largo para disuadir bypass
- ✅ Opción de pregunta/email OPCIONAL
- ✅ Sin dependencia de servicios externos

---

## FASE 3: USABILIDAD AVANZADA

**Objetivo**: Hacer la app más flexible y potente sin sacrificar minimalismo

### Sprint 16 — Perfiles de Restricción (2 semanas)

**Historia 1**: Sistema de perfiles (5 SP)

**Como** usuario
**Quiero** crear diferentes conjuntos de restricciones
**Para** activarlos según contexto

**Funcionalidades**:

1. **Gestión de perfiles**:
   - Crear perfil nuevo con nombre
   - Cada perfil = conjunto independiente de restricciones
   - Perfil "Default" siempre existe
   - Máximo 5 perfiles

2. **Configuración por perfil**:
   - Al editar restricción: se guarda en perfil activo
   - Perfiles independientes entre sí
   - Mismo app puede tener cuotas diferentes en cada perfil
   - WiFi bloqueadas también por perfil

3. **Activación de perfil**:
   - Selector en pantalla principal
   - Cambio instantáneo
   - Notificación de cambio
   - Ultimo perfil usado se recuerda

**Ejemplos de uso**:
```
Perfil "Trabajo" (Lunes-Viernes):
  - Instagram: 5 min/día
  - TikTok: 0 min/día (bloqueado total)
  - YouTube: 15 min/día
  - Reddit: bloqueado en WiFi "OfficeNetwork"

Perfil "Fin de Semana":
  - Instagram: 60 min/día
  - TikTok: 30 min/día
  - YouTube: 120 min/día
  - Sin bloqueos por WiFi

Perfil "Estudio":
  - Instagram: 0 min/día
  - TikTok: 0 min/día
  - YouTube: 0 min/día
  - Reddit: 0 min/día
  - WhatsApp: permitido
```

**Historia 2**: Activación automática (3 SP)

**Como** usuario
**Quiero** que perfiles se activen automáticamente
**Para** no tener que cambiarlos manualmente

**Reglas de activación**:
- Por horario: "Trabajo" de 9am-6pm Lun-Vie
- Por día de semana: "Fin de Semana" Sáb-Dom
- Por WiFi conectada: "Estudio" cuando WiFi = "BibliotecaUni"
- Prioridad: WiFi > Horario > Manual

**Criterios de aceptación**:
- ✅ Mínimo 3 perfiles configurables
- ✅ Cambio de perfil sin reinicio de app
- ✅ Activación automática funciona en background
- ✅ Export/import incluye todos los perfiles

---

### Sprint 17 — Excepciones Temporales (1 semana)

**Historia 1**: Desbloqueo temporal (3 SP)

**Como** usuario
**Quiero** poder desbloquear una app por tiempo limitado
**Para** casos de emergencia

**Funcionalidades**:
- Botón "Desbloquear temporalmente" en card de app bloqueada
- Requiere PIN si modo admin activo
- Opciones: 5 min / 10 min / 15 min / 30 min
- Contador visible en notificación persistente
- Al terminar tiempo: bloqueo automático nuevamente
- No afecta cuota diaria (tiempo usado cuenta normal)

**Historia 2**: Límite de excepciones (2 SP)

**Para prevenir abuso**:
- Máximo 3 excepciones por día por app
- Máximo 1 hora total de excepciones por día
- Contador visible: "Excepciones usadas hoy: 1/3"
- Reset a medianoche junto con cuotas

**Historia 3**: Log de excepciones (1 SP)

**Para awareness**:
- Registrar cada excepción en activity log
- Formato: "[Hoy 15:30] ⏱️ Instagram desbloqueada 15 min (excepción temporal)"
- Al final del día: resumen de excepciones usadas

**Criterios de aceptación**:
- ✅ Excepción termina automáticamente
- ✅ Notificación con countdown visible
- ✅ No se puede extender excepción activa
- ✅ Límites diarios funcionan correctamente

---

### Sprint 18 — Bloqueo por Horario (1-2 semanas)

**Historia 1**: Configuración de horarios (5 SP)

**Como** usuario
**Quiero** bloquear apps en horarios específicos
**Para** evitar distracciones en momentos clave

**Nueva entidad de datos**:
```kotlin
TimeRestriction:
  - id: String
  - packageName: String
  - blockedTimeRanges: List<TimeRange>

TimeRange:
  - startHour: Int (0-23)
  - startMinute: Int (0-59)
  - endHour: Int
  - endMinute: Int
  - daysOfWeek: Set<DayOfWeek> // Lun, Mar, Mié...
```

**UI de configuración**:
- En card de app: botón "Horarios bloqueados"
- Diálogo con time pickers de inicio/fin
- Selector de días de semana (chips)
- Múltiples rangos horarios permitidos
- Vista previa: "Bloqueada Lun-Vie 9:00-18:00"

**Ejemplos**:
```
Instagram:
  - Lunes-Viernes: 9:00-18:00 (horario laboral)
  - Todos los días: 23:00-07:00 (horario de sueño)

YouTube:
  - Lunes-Viernes: 8:00-17:00
```

**Historia 2**: Motor de bloqueo horario (3 SP)

**Integración con BlockingEngine**:
```kotlin
suspend fun shouldBlock(packageName: String): Boolean {
    // Verificar cuota (existente)
    if (isQuotaBlocked(packageName)) return true

    // Verificar WiFi (existente)
    if (isWifiBlocked(packageName)) return true

    // NUEVO: Verificar horario
    if (isTimeBlocked(packageName)) return true

    return false
}

suspend fun isTimeBlocked(packageName: String): Boolean {
    val timeRestriction = db.getTimeRestriction(packageName) ?: return false
    val now = LocalDateTime.now()
    val currentDay = now.dayOfWeek
    val currentTime = LocalTime.of(now.hour, now.minute)

    return timeRestriction.blockedTimeRanges.any { range ->
        currentDay in range.daysOfWeek &&
        currentTime in range.timeRange
    }
}
```

**Historia 3**: Notificaciones de horario (2 SP)

- 5 min antes de entrar a bloqueo: "Instagram se bloqueará en 5 minutos"
- Al entrar: "Instagram bloqueada hasta las 18:00"
- Al salir: "Instagram disponible nuevamente"
- Configurables en settings de notificaciones

**Criterios de aceptación**:
- ✅ Bloqueo por horario funciona en background
- ✅ Combinable con cuota diaria y WiFi
- ✅ Múltiples rangos horarios por app
- ✅ Precisión de ±1 minuto

---

### Sprint 19 — Quick Actions y Usabilidad (1 semana)

**Historia 1**: Widget de Android (5 SP)

**Como** usuario
**Quiero** ver tiempo restante sin abrir la app
**Para** tener visibilidad rápida

**Widget pequeño (2x1)**:
```
┌─────────────────┐
│ AppTimeControl  │
│ Instagram: 15m  │
│ YouTube: 1h 20m │
└─────────────────┘
```

**Widget mediano (4x1)**:
```
┌───────────────────────────────┐
│ AppTimeControl                │
│ Instagram  [====    ] 25m/60m │
│ TikTok     [===     ] 5m/30m  │
│ YouTube    [========] 50m/60m │
└───────────────────────────────┘
```

**Actualización**:
- Cada 5 minutos en foreground
- Cada 15 minutos en background
- Al abrir/cerrar app monitoreada

**Historia 2**: Notificación permanente colapsable (2 SP)

**Notificación ongoing**:
- Prioridad mínima (no molesta)
- Colapsada: "AppTimeControl activo"
- Expandida: Lista de apps con tiempo restante
- Tap: abre app principal
- Acciones: "Ver perfiles", "Logs"

**Historia 3**: Edición rápida en lista (3 SP)

**Mejoras de UX**:
- Long-press en card: menú contextual
  - "Editar cuota"
  - "Ver historial"
  - "Desbloqueo temporal"
  - "Eliminar restricción"
- Slider inline para cambiar cuota sin diálogo
- Swipe actions:
  - Swipe derecha: Editar
  - Swipe izquierda: Eliminar

**Criterios de aceptación**:
- ✅ Widget actualiza automáticamente
- ✅ Notificación persistente sin molestar
- ✅ Edición rápida funciona sin bugs
- ✅ Performance fluido en todas las interacciones

---

## FASE 4: PREVENCIÓN DE BYPASS

**Objetivo**: Cerrar todas las formas conocidas de evadir restricciones

### Sprint 20 — Detección Inteligente (1-2 semanas)

**Historia 1**: Apps duplicadas y clones (5 SP)

**Como** sistema
**Quiero** detectar cuando usuario instala clone de app restringida
**Para** bloquearla automáticamente

**Funcionalidades**:

1. **Detección de clones**:
   - Comparar firma de app con apps conocidas
   - Detectar apps clonadas con herramientas (Parallel Space, etc)
   - Base de datos de equivalencias:
     ```
     Instagram = {
       com.instagram.android,
       com.instagram.lite,
       instagram.clone.*
     }

     Twitter/X = {
       com.twitter.android,
       com.twitter.android.lite,
       com.x.android
     }
     ```

2. **Auto-aplicar restricciones**:
   - Si Instagram tiene cuota de 30 min
   - Usuario instala Instagram Lite
   - Sistema pregunta: "Instagram Lite detectado. ¿Aplicar misma cuota que Instagram?"
   - Si acepta: cuota compartida entre ambas apps

3. **Lista de variantes conocidas**:
   - Mantenida manualmente en resources
   - Actualizable con updates de app
   - Incluye 50+ apps más populares

**Historia 2**: Monitor de instalaciones (3 SP)

**Funcionalidades**:
- BroadcastReceiver para PACKAGE_ADDED
- Al instalar nueva app: verificar si es red social conocida
- Categorías predefinidas:
  - Redes sociales: Instagram, TikTok, Twitter, Facebook...
  - Streaming: YouTube, Netflix, Twitch...
  - Juegos: Free Fire, PUBG, Call of Duty...
  - Dating: Tinder, Bumble, Badoo...
- Sugerir cuota según categoría
- Notificación: "Nueva app detectada: TikTok. ¿Agregar restricción?"

**Historia 3**: Detección de navegadores web (4 SP)

**Como** sistema
**Quiero** bloquear sitios web específicos en navegadores
**Para** prevenir bypass usando versión web

**Implementación**:

1. **Configuración por app**:
   - Nueva opción: "Bloquear también en navegadores"
   - Lista de URLs equivalentes:
     ```
     Instagram → instagram.com, instagram.com/*, m.instagram.com
     Twitter → twitter.com, x.com, mobile.twitter.com
     YouTube → youtube.com, m.youtube.com, youtu.be
     ```

2. **Detección de navegadores**:
   - Lista de navegadores populares:
     - Chrome, Firefox, Opera, Brave, Edge, Samsung Internet
   - Al abrir navegador: verificar URL con AccessibilityService
   - Si URL match con bloqueada: mostrar overlay

3. **Limitaciones conocidas**:
   - Solo funciona con AccessibilityService activo
   - Puede tener falsos positivos
   - Funciona mejor en Chrome/Samsung que en otros

**Criterios de aceptación**:
- ✅ Detecta clones de 90% de apps populares
- ✅ Notifica instalación de apps tentadoras
- ✅ Bloquea versiones web de apps en Chrome/Samsung
- ✅ Sin falsos positivos en sitios legítimos

---

## FASE 5: OPTIMIZACIÓN Y PULIDO

**Objetivo**: Mejorar rendimiento, batería y experiencia general

### Sprint 21 — Optimizaciones Técnicas (1 semana)

**Historia 1**: Modo ahorro de batería (3 SP)

**Funcionalidades**:
- Detectar nivel de batería < 20%
- Reducir frecuencia de monitoreo: 30s → 2 min
- Pausar tracking detallado
- Mantener solo bloqueos activos
- Continuar detección de apps abiertas
- Notificar al usuario: "Modo ahorro activado"

**Historia 2**: Cache inteligente (2 SP)

**Optimizaciones**:
- Cachear lista de apps instaladas en SharedPreferences
- Actualizar solo cuando recibe PACKAGE_ADDED/REMOVED
- Evitar llamadas repetidas a PackageManager
- Cache de íconos de apps (si se implementan)
- TTL de 24h para cache de redes WiFi

**Historia 3**: Compresión de base de datos (3 SP)

**Funcionalidades**:
- Job scheduler semanal de limpieza
- Purgar daily_usage > 30 días
- Purgar activity_logs > 30 días
- Comprimir backups antiguos
- Export a CSV antes de purgar (opcional)
- Vacuum database tras purga

**Criterios de aceptación**:
- ✅ Consumo de batería < 2% diario en modo ahorro
- ✅ Tiempo de carga de lista de apps < 500ms
- ✅ Tamaño de DB < 10MB tras 3 meses de uso
- ✅ Sin lag perceptible en UI

---

### Sprint 22 — Accesibilidad (1 semana)

**Historia 1**: Light Mode (3 SP)

**Funcionalidades**:
- Tema claro completo
- Colores adaptados a luz diurna
- Contraste WCAG AAA
- Toggle manual en settings
- Opción "Seguir sistema"

**Historia 2**: Tamaños de texto (2 SP)

**Funcionalidades**:
- Respetar configuración de sistema
- Soporte para tamaños grandes
- Testing con accesibilidad de Android
- Layout adaptativo sin overlaps

**Historia 3**: TalkBack optimization (3 SP)

**Funcionalidades**:
- Todas las acciones accesibles por voz
- Descripciones semánticas completas
- Orden de navegación lógico
- Anuncios de cambios de estado
- Testing con TalkBack activo

**Criterios de aceptación**:
- ✅ Light mode sin problemas de contraste
- ✅ Funcional con texto 200% tamaño
- ✅ Navegación completa con TalkBack
- ✅ Pasa auditoría de accesibilidad de Android

---

## RESUMEN DE ROADMAP COMPLETO

### COMPLETADO (Sprint 1-10)
- ✅ MVP Alpha (6 sprints)
- ✅ Notificaciones (1 sprint)
- ✅ Export/Import (1 sprint)

### PENDIENTE

**FASE 1: Correcciones Críticas** (2-4 semanas)
- Sprint 11: Detección completa de apps + WiFi + Protección desinstalación
- Sprint 12: UI Material Design 3

**FASE 2: Persistencia** (3 semanas)
- Sprint 13: Backup automático
- Sprint 14: Logs de actividad
- Sprint 15: Recuperación de PIN

**FASE 3: Usabilidad** (5-6 semanas)
- Sprint 16: Perfiles de restricción
- Sprint 17: Excepciones temporales
- Sprint 18: Bloqueo por horario
- Sprint 19: Quick actions y widget

**FASE 4: Anti-bypass** (1-2 semanas)
- Sprint 20: Detección inteligente

**FASE 5: Optimización** (2 semanas)
- Sprint 21: Optimizaciones técnicas
- Sprint 22: Accesibilidad

---

## TIMELINE ESTIMADO

```
Hoy (completado):      Sprint 1-10  (6-8 semanas)
Fase 1 (crítico):      Sprint 11-12 (2-4 semanas)
Fase 2 (persistencia): Sprint 13-15 (3 semanas)
Fase 3 (usabilidad):   Sprint 16-19 (5-6 semanas)
Fase 4 (anti-bypass):  Sprint 20    (1-2 semanas)
Fase 5 (optimización): Sprint 21-22 (2 semanas)

TOTAL: 19-25 semanas adicionales (4.5-6 meses)
```

**Release 2.0 (completo)**: Mayo-Julio 2026