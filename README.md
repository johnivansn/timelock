# TimeLock

**Control temporal minimalista para Android — Bloqueo real que funciona**

<div align="center">

![Android](https://img.shields.io/badge/Android-10%2B-3DDC84?style=flat&logo=android)
![Flutter](https://img.shields.io/badge/Flutter-Latest-02569B?style=flat&logo=flutter)
![Kotlin](https://img.shields.io/badge/Kotlin-2.2.20-7F52FF?style=flat&logo=kotlin)
![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat)
![Release](https://img.shields.io/github/v/release/johnivansn/timelock?style=flat&label=Release)

[Características](#características) • [Instalación](#instalación) • [Uso](#cómo-funciona) • [FAQ](#preguntas-frecuentes)

</div>

---

## ¿Qué es TimeLock?

TimeLock es una aplicación Android de control de tiempo de pantalla **sin trucos, sin gamificación, sin estadísticas innecesarias**. Solo restricción directa y efectiva.

A diferencia de otras apps de "digital wellbeing", TimeLock:

- **Realmente bloquea**: No puedes cancelar el bloqueo
- **100% local**: Sin tracking, sin cuentas, sin internet
- **Ligera**: <2% batería/día, <30MB RAM
- **Flexible**: Cuotas diarias/semanales + bloqueos por horario/fecha
- **Protegida**: PIN no recuperable (deliberadamente)

> **Filosofía**: Menos es más. TimeLock es para personas que buscan **auto-control real**, no una app más de "motivación".

---

## ✨ Características

### 🕒 Control de Tiempo
- **Cuotas diarias**: 1-480 minutos por app, mismo tiempo o diferente por día
- **Cuotas semanales**: Límite total semanal con reseteo configurable
- **Bloqueo automático**: Overlay visual + redirección forzada a HOME
- **Precisión**: Tracking basado en UsageStats API nativa de Android

### 📅 Bloqueos Directos
- **Por horario**: Define rangos (ej: 22:00-06:00) con días de la semana
- **Por fecha**: Bloquea en períodos específicos con hora de inicio/fin
- **Vencimiento opcional**: Restricciones que expiran automáticamente
- **Templates**: Guarda configuraciones para reutilizar

### 🔐 Seguridad
- **Modo Administrador**: Protección con PIN de 4 dígitos (SHA-256)
- **Bloqueo temporal**: Activa modo admin por tiempo limitado sin PIN
- **Anti-bypass**: 3 intentos fallidos → bloqueo de 5 minutos
- **Sin recuperación**: Si olvidas tu PIN, debes reinstalar (decisión consciente)

### 🎨 Experiencia de Usuario
- **Material Design 3**: UI moderna con tema claro/oscuro
- **Notificaciones inteligentes**: Píldoras flotantes o notificaciones normales
- **Widget**: Lista rápida de restricciones sin abrir la app
- **Export/Import**: Backup completo de tu configuración en JSON

### ⚡ Optimización
- **Modo ahorro de batería**: Reduce frecuencia de tracking (2% → 0.5% batería/día)
- **Cache inteligente**: Iconos en memoria según disponibilidad de RAM
- **Limpieza automática**: Purga datos antiguos cada 24h
- **Updates desde GitHub**: Actualización manual con rollback

---

## 📱 Requisitos

- **Android 10+** (API 29+)
- **Dispositivo físico** (emuladores tienen limitaciones con UsageStats)
- **~50MB** espacio de almacenamiento

### Permisos necesarios

| Permiso | Criticidad | Propósito |
|---------|-----------|-----------|
| Usage Stats | **CRÍTICO** | Tracking de uso de apps |
| Accessibility Service | **CRÍTICO** | Bloquear apps y mostrar overlay si está disponible |
| Display over other apps | RECOMENDADO | Notificaciones visuales (píldora) |
| Device Admin | OPCIONAL | Protección contra desinstalación |

> **Nota**: Si tu dispositivo bloquea "Mostrar sobre otras apps", TimeLock usa notificaciones normales + bloqueo lógico

---

## 🚀 Instalación

### Opción 1: Desde Releases (Recomendado)

1. Ve a [Releases](https://github.com/johnivansn/timelock/releases)
2. Descarga el APK más reciente
3. Instala en tu dispositivo
4. Sigue el asistente de permisos en la app

### Opción 2: Compilar desde código

```bash
# 1. Clonar repositorio
git clone https://github.com/johnivansn/timelock.git
cd timelock

# 2. Instalar dependencias
flutter pub get

# 3. Conectar dispositivo Android
# Verificar: flutter devices

# 4. Compilar e instalar
flutter run --release
```

**Requisitos de desarrollo**:
- Flutter SDK (stable channel)
- Android Studio / VS Code
- JDK 17+
- Gradle 8.14+

---

## 🎮 Cómo Funciona

### Setup Inicial (< 2 minutos)

1. **Permisos**: La app te guía para habilitar permisos críticos
2. **Apps**: Selecciona apps que quieres controlar
3. **Límites**: Define cuotas diarias/semanales o bloqueos directos
4. **Opcional**: Configura PIN para proteger cambios

### Tipos de Restricción

#### Cuota Diaria/Semanal
```
Instagram: 30 minutos/día
→ Uso alcanza 30 min
→ Bloqueo automático hasta medianoche (o próximo reseteo semanal)
```

#### Bloqueo por Horario
```
TikTok: Bloqueado de 22:00 a 06:00 (Lun-Vie)
→ Son las 21:55
→ Notificación: "TikTok se bloqueará en 5 min"
→ Son las 22:00
→ App bloqueada hasta las 06:00
```

#### Bloqueo por Fecha
```
YouTube: Bloqueado del 10-15 Feb (08:00-20:00)
Etiqueta: "Semana de exámenes"
→ Durante ese período (en horario definido)
→ App completamente bloqueada
```

### Comportamiento de Bloqueo

**Con overlay habilitado**:
- Pantalla de bloqueo no cancelable
- Countdown de 5 segundos
- Redirección automática a HOME

**Sin overlay (fallback)**:
- Notificación normal con mensaje de bloqueo
- Redirección inmediata a HOME

---

## 🛡️ Privacidad y Seguridad

### Lo que TimeLock HACE
- Monitorea tiempo de uso **localmente** usando Android UsageStats API
- Almacena configuración en base de datos SQLite **local**
- Bloquea apps mediante AccessibilityService **sin enviar datos**

### Lo que TimeLock NO HACE
- No requiere cuenta ni login
- No envía datos a servidores externos
- No tiene tracking ni analytics
- No requiere conexión a internet (excepto para updates manuales)

### Almacenamiento de PIN
- Hash SHA-256 (irreversible)
- Sin recuperación posible (deliberado)
- Almacenado localmente en Room DB

---

## ❓ Preguntas Frecuentes

<details>
<summary><b>¿Puedo evitar el bloqueo desinstalando la app?</b></summary>

Sí, con esfuerzo. TimeLock usa Device Admin (opcional) que dificulta la desinstalación, pero no es infalible. **Esto es deliberado**: TimeLock es para auto-control, no control parental estricto.
</details>

<details>
<summary><b>¿Qué pasa si olvido mi PIN?</b></summary>

Debes reinstalar la app. **No hay forma de recuperarlo**. Esto es una decisión consciente de diseño para mantener la seriedad del compromiso.
</details>

<details>
<summary><b>¿Por qué necesita Accessibility Service?</b></summary>

Para detectar qué app está en primer plano y mostrar el overlay de bloqueo. Sin este permiso, la app solo puede trackear uso pero no puede bloquear efectivamente.
</details>

<details>
<summary><b>¿El bloqueo puede fallar?</b></summary>

En casos extremos:
- Launchers muy agresivos (MIUI, ColorOS) pueden bloquear overlays
- UsageStats tiene ~30s de latencia (usuario podría usar 30s extra)
- Modo desarrollador puede desactivar servicios

**Solución**: TimeLock funciona mejor en Android stock o launchers estándar.
</details>

<details>
<summary><b>¿Consume mucha batería?</b></summary>

No. Consumo promedio:
- Modo normal: ~1.5% batería/día
- Modo ahorro: ~0.5% batería/día
</details>

<details>
<summary><b>¿Puedo exportar mi configuración?</b></summary>

Sí. Export/Import en formato JSON incluye:
- Restricciones (cuotas diarias/semanales)
- Horarios
- Bloqueos por fecha
- Templates

**No incluye**: PIN, contadores de uso diario.
</details>

---

## 🗺️ Roadmap

### ✅ Completado (v0.1.x)
- Cuotas diarias y semanales
- Bloqueos por horario
- Bloqueos por fecha con hora
- Vencimiento opcional de restricciones
- Modo admin con PIN y bloqueo temporal
- Material Design 3 con variantes de tema
- Widget de lista (scrolleable)
- Export/Import JSON
- Optimización de batería
- Updates desde GitHub Releases

### 🔮 Considerado para Futuro
- Modo Familia (múltiples perfiles)
- Backup en nube opcional (privacy-first)
- Logs exportables para debugging
- Anti-bypass avanzado (detección de side-loading)

### ❌ Descartado Permanentemente
- Bloqueo por WiFi (demasiado complejo)
- Gamificación (anti-filosofía del proyecto)
- Estadísticas detalladas (minimalismo)

---

## 🤝 Contribuir

**Actualmente**: Proyecto en desarrollo individual. No se aceptan contribuciones externas en esta etapa.

Si encuentras bugs o tienes sugerencias:
1. Abre un [Issue](https://github.com/johnivansn/timelock/issues)
2. Describe el problema con detalle
3. Incluye logs si es posible (`adb logcat`)

---

## 📄 Licencia

MIT License - Ver [LICENSE](LICENSE) para más detalles.

En resumen: puedes usar, modificar y distribuir este software, incluyendo uso comercial, siempre que incluyas la licencia y el aviso de copyright.

---

## 🙏 Agradecimientos

- **Flutter Team**: Por el excelente framework
- **Android Open Source Project**: Por UsageStats API y AccessibilityService
- **Material Design**: Por las guías de diseño

---

## 📞 Contacto

- **Issues**: [GitHub Issues](https://github.com/johnivansn/timelock/issues)
- **Discusiones**: [GitHub Discussions](https://github.com/johnivansn/timelock/discussions)

---

<div align="center">

**TimeLock — Menos apps, más vida**

</div>
