/* eslint-disable max-len */
/* eslint-disable padded-blocks */
/* eslint-disable indent */
/* eslint-disable no-async-promise-executor */
/* eslint-disable arrow-parens */
/* eslint-disable prefer-promise-reject-errors */
/* eslint-disable no-trailing-spaces */
/* eslint-disable require-jsdoc */
/* eslint-disable object-curly-spacing */
/* eslint-disable quotes */
const io = require('socket.io-client');
const pool = require('../config/database');
const { v4: uuidv4 } = require('uuid');

class WebSocketManager {
  constructor() {
    this.socket = null;
    this.isConnected = false;
    this.pendingTransfers = new Map(); // transferId -> { resolve, reject, timeout }
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
    this.reconnectDelay = 3000; // 3 segundos
    
    // Configuración del banco
    this.config = {
      bankId: 'B02',
      bankName: 'Banca Capital Nacional',
      centralBankUrl: 'http://137.184.36.3:6000',
      token: 'BANK-CENTRAL-IC8057-2025',
      transferTimeout: 120000, // 2 minutos
    };
  }

  // ============================================
  // CONEXIÓN Y GESTIÓN DE SOCKET
  // ============================================

  connect() {
    if (this.isConnected && this.socket) {
      console.log('[WebSocket] Ya está conectado');
      return;
    }

    console.log('[WebSocket] Conectando al Banco Central...');
    console.log(`[WebSocket] URL: ${this.config.centralBankUrl}`);
    console.log(`[WebSocket] Banco: ${this.config.bankId} - ${this.config.bankName}`);

    this.socket = io(this.config.centralBankUrl, {
      transports: ['websocket'],
      auth: {
        bankId: this.config.bankId,
        bankName: this.config.bankName,
        token: this.config.token,
      },
      reconnection: true,
      reconnectionAttempts: this.maxReconnectAttempts,
      reconnectionDelay: this.reconnectDelay,
    });

    this.setupEventHandlers();
  }

  setupEventHandlers() {
    // Evento: Conexión exitosa
    this.socket.on('connect', () => {
      this.isConnected = true;
      this.reconnectAttempts = 0;
      console.log('[WebSocket] Conectado al Banco Central');
      console.log(`[WebSocket] Socket ID: ${this.socket.id}`);
    });

    // Evento: Desconexión
    this.socket.on('disconnect', (reason) => {
      this.isConnected = false;
      console.log(`[WebSocket] Desconectado. Razon: ${reason}`);
      
      if (reason === 'io server disconnect') {
        // El servidor forzó la desconexión, reconectar manualmente
        this.socket.connect();
      }
    });

    // Evento: Error de conexión
    this.socket.on('connect_error', (error) => {
      this.reconnectAttempts++;
      console.error(`[WebSocket] Error de conexion (intento ${this.reconnectAttempts}):`, error.message);
      
      if (this.reconnectAttempts >= this.maxReconnectAttempts) {
        console.error('[WebSocket] Maximo de intentos de reconexion alcanzado');
      }
    });

    // Evento: Reconexión exitosa
    this.socket.on('reconnect', (attemptNumber) => {
      console.log(`[WebSocket] Reconectado despues de ${attemptNumber} intentos`);
    });

    // ============================================
    // EVENTOS DE TRANSFERENCIAS
    // ============================================

    // Evento: transfer.reserve (congelar fondos)
    this.socket.on('transfer.reserve', async (data) => {
      await this.handleReserve(data);
    });

    // Evento: transfer.init (notificación informativa - banco destino)
    this.socket.on('transfer.init', async (data) => {
      await this.handleInit(data);
    });

    // Evento: transfer.credit (acreditar fondos - banco destino)
    this.socket.on('transfer.credit', async (data) => {
      await this.handleCredit(data);
    });

    // Evento: transfer.debit (debitar fondos - banco origen)
    this.socket.on('transfer.debit', async (data) => {
      await this.handleDebit(data);
    });

    // Evento: transfer.commit (confirmar transferencia)
    this.socket.on('transfer.commit', async (data) => {
      await this.handleCommit(data);
    });

    // Evento: transfer.rollback (revertir transferencia)
    this.socket.on('transfer.rollback', async (data) => {
      await this.handleRollback(data);
    });

    // Evento: transfer.reject (rechazar transferencia)
    this.socket.on('transfer.reject', async (data) => {
      await this.handleReject(data);
    });
  }

  disconnect() {
    if (this.socket) {
      console.log('[WebSocket] Desconectando...');
      this.socket.disconnect();
      this.socket = null;
      this.isConnected = false;
    }
  }

  // ============================================
  // INICIAR TRANSFERENCIA INTERBANCARIA
  // ============================================

  async initiateTransfer(transferData) {
    return new Promise(async (resolve, reject) => {
      try {
        // Validar conexión
        if (!this.isConnected) {
          this.connect();
          // Esperar 2 segundos para conexión
          await new Promise(r => setTimeout(r, 2000));
          
          if (!this.isConnected) {
            return reject({
              success: false,
              code: 'CONNECTION_ERROR',
              message: 'No se pudo conectar al Banco Central',
            });
          }
        }

        // Generar ID único para la transferencia
        const transferId = uuidv4();
        
        console.log('[WebSocket] Iniciando transferencia interbancaria');
        console.log(`[WebSocket] Transfer ID: ${transferId}`);
        console.log(`[WebSocket] From: ${transferData.from} → To: ${transferData.to}`);
        console.log(`[WebSocket] Amount: ${transferData.currency} ${transferData.amount}`);

        // Extraer códigos de banco
        const fromBank = transferData.from.substring(4, 7); // "B02"
        const toBank = transferData.to.substring(4, 7);

        // Validar que sea interbancaria
        if (fromBank === toBank) {
          return reject({
            success: false,
            code: 'SAME_BANK',
            message: 'Use transferencia interna para cuentas del mismo banco',
          });
        }

        // Registrar en base de datos
        const dbResult = await pool.query(
          `INSERT INTO transferencia_interbancaria 
           (transfer_id_ws, cuenta_origen_id, cuenta_destino_iban, monto, moneda, 
            descripcion, estado, banco_origen, banco_destino)
           VALUES ($1, 
                   (SELECT id FROM cuenta WHERE iban = $2), 
                   $3, $4, 
                   (SELECT id FROM moneda WHERE iso = $5),
                   $6, 'pending', $7, $8)
           RETURNING id`,
          [
            transferId,
            transferData.from,
            transferData.to,
            transferData.amount,
            transferData.currency,
            transferData.description || '',
            fromBank,
            toBank,
          ],
        );

        console.log(`[WebSocket] Registro en BD creado (ID: ${dbResult.rows[0].id})`);

        // Configurar timeout
        const timeout = setTimeout(() => {
          this.pendingTransfers.delete(transferId);
          reject({
            success: false,
            code: 'TIMEOUT',
            message: 'La operación tardó demasiado tiempo',
          });
        }, this.config.transferTimeout);

        // Guardar en pendientes
        this.pendingTransfers.set(transferId, { resolve, reject, timeout });

        // Enviar evento transfer.intent al Banco Central
        const intentPayload = {
          id: transferId,
          from: transferData.from,
          to: transferData.to,
          amount: transferData.amount,
          currency: transferData.currency,
          description: transferData.description || '',
        };

        console.log('[WebSocket] Enviando transfer.intent...');
        this.socket.emit('transfer.intent', intentPayload);

        // Registrar evento
        await this.logEvent(transferId, 'transfer.intent', intentPayload, fromBank, toBank, 'sent');

      } catch (error) {
        console.error('[WebSocket] Error al iniciar transferencia:', error);
        reject({
          success: false,
          code: 'INTERNAL_ERROR',
          message: error.message || 'Error interno del servidor',
        });
      }
    });
  }

  // ============================================
  // HANDLERS DE EVENTOS
  // ============================================

  async handleReserve(data) {
    console.log('[WebSocket] Evento recibido: transfer.reserve');
    console.log('[WebSocket] Data:', JSON.stringify(data, null, 2));

    const { id: transferId } = data;

    try {
      // Buscar transferencia en BD
      const transferResult = await pool.query(
        `SELECT * FROM transferencia_interbancaria WHERE transfer_id_ws = $1`,
        [transferId],
      );

      if (transferResult.rows.length === 0) {
        console.error(`[WebSocket] Transferencia no encontrada: ${transferId}`);
        this.socket.emit('transfer.reserve.result', {
          id: transferId,
          ok: false,
          reason: 'TRANSFER_NOT_FOUND',
        });
        return;
      }

      const transfer = transferResult.rows[0];

      // Obtener cuenta origen
      const cuentaResult = await pool.query(
        `SELECT * FROM cuenta WHERE id = $1`,
        [transfer.cuenta_origen_id],
      );

      if (cuentaResult.rows.length === 0) {
        console.error(`[WebSocket] Cuenta origen no encontrada`);
        this.socket.emit('transfer.reserve.result', {
          id: transferId,
          ok: false,
          reason: 'ACCOUNT_NOT_FOUND',
        });
        return;
      }

      const cuenta = cuentaResult.rows[0];

      // Validar fondos suficientes (incluyendo reservas existentes)
      const reservasResult = await pool.query(
        `SELECT COALESCE(SUM(monto), 0) as total_reservado 
         FROM transferencia_reserva 
         WHERE cuenta_id = $1 AND estado = 'active'`,
        [cuenta.id],
      );

      const saldoDisponible = parseFloat(cuenta.saldo) - parseFloat(reservasResult.rows[0].total_reservado);

      if (saldoDisponible < parseFloat(transfer.monto)) {
        console.error(`[WebSocket] Fondos insuficientes`);
        console.error(`[WebSocket] Saldo: ${cuenta.saldo}, Reservado: ${reservasResult.rows[0].total_reservado}, Disponible: ${saldoDisponible}`);
        
        this.socket.emit('transfer.reserve.result', {
          id: transferId,
          ok: false,
          reason: 'NO_FUNDS',
        });
        
        await this.logEvent(transferId, 'transfer.reserve.result', { ok: false, reason: 'NO_FUNDS' }, 
                          transfer.banco_origen, transfer.banco_destino, 'sent');
        return;
      }

      // Crear reserva
      await pool.query(
        `INSERT INTO transferencia_reserva 
         (transfer_id_ws, cuenta_id, monto, descripcion, cuenta_destino_iban, fecha_expiracion)
         VALUES ($1, $2, $3, $4, $5, NOW() + INTERVAL '5 minutes')`,
        [transferId, cuenta.id, transfer.monto, transfer.descripcion, transfer.cuenta_destino_iban],
      );

      // Actualizar estado de transferencia
      await pool.query(
        `UPDATE transferencia_interbancaria SET estado = 'reserved' WHERE transfer_id_ws = $1`,
        [transferId],
      );

      console.log('[WebSocket] Fondos reservados exitosamente');

      // Responder al Banco Central
      this.socket.emit('transfer.reserve.result', {
        id: transferId,
        ok: true,
      });

      await this.logEvent(transferId, 'transfer.reserve.result', { ok: true }, 
                        transfer.banco_origen, transfer.banco_destino, 'sent');

    } catch (error) {
      console.error('[WebSocket] Error en handleReserve:', error);
      this.socket.emit('transfer.reserve.result', {
        id: transferId,
        ok: false,
        reason: 'INTERNAL_ERROR',
      });
    }
  }

  async handleInit(data) {
    console.log('[WebSocket] Evento recibido: transfer.init (informativo)');
    console.log('[WebSocket] Data:', JSON.stringify(data, null, 2));

    const { id: transferId } = data;

    // Este evento es solo informativo
    // Registrar en logs para auditoría
    const fromBank = data.from ? data.from.substring(4, 7) : null;
    const toBank = data.to ? data.to.substring(4, 7) : null;
    await this.logEvent(transferId, 'transfer.init', data, fromBank, toBank, 'received');

    console.log('[WebSocket] Notificacion de transferencia entrante registrada');
  }

  async handleCredit(data) {
    console.log('[WebSocket] Evento recibido: transfer.credit');
    console.log('[WebSocket] Data:', JSON.stringify(data, null, 2));

    // Este evento es para el BANCO DESTINO (cuando recibe dinero)
    // Como somos B02, solo procesamos si es para nosotros
    
    const { id: transferId, to } = data;
    const toBank = to.substring(4, 7);

    if (toBank !== this.config.bankId) {
      console.log(`[WebSocket] transfer.credit no es para este banco (destino: ${toBank})`);
      return;
    }

    try {
      // Buscar cuenta destino
      const cuentaResult = await pool.query(
        `SELECT * FROM cuenta WHERE iban = $1`,
        [to],
      );

      if (cuentaResult.rows.length === 0) {
        console.error(`[WebSocket] Cuenta destino no encontrada: ${to}`);
        this.socket.emit('transfer.credit.result', {
          id: transferId,
          ok: false,
          reason: 'ACCOUNT_NOT_FOUND',
        });
        return;
      }

      const cuenta = cuentaResult.rows[0];

      // Crear movimiento de crédito temporal (pendiente)
      const movimientoResult = await pool.query(
        `INSERT INTO movimientoCuenta 
         (cuenta_id, fecha, tipo, descripcion, moneda, monto, referencia)
         VALUES ($1, NOW(), 
                 (SELECT id FROM tipoMovimientoCuenta WHERE nombre = 'Crédito'),
                 $2,
                 $3,
                 $4,
                 $5)
         RETURNING id`,
        [
          cuenta.id,
          `Transferencia interbancaria recibida - ${data.description || ''}`,
          cuenta.moneda,
          data.amount,
          `WS-${transferId}`,
        ],
      );

      console.log(`[WebSocket] Movimiento de credito creado (ID: ${movimientoResult.rows[0].id})`);

      // Responder éxito
      this.socket.emit('transfer.credit.result', {
        id: transferId,
        ok: true,
      });

      const fromBank = data.from ? data.from.substring(4, 7) : null;
      await this.logEvent(transferId, 'transfer.credit.result', { ok: true }, fromBank, toBank, 'sent');

    } catch (error) {
      console.error('[WebSocket] Error en handleCredit:', error);
      this.socket.emit('transfer.credit.result', {
        id: transferId,
        ok: false,
        reason: 'CREDIT_FAILED',
      });
    }
  }

  async handleDebit(data) {
    console.log('[WebSocket] Evento recibido: transfer.debit');
    console.log('[WebSocket] Data:', JSON.stringify(data, null, 2));

    const { id: transferId } = data;

    try {
      // Buscar transferencia
      const transferResult = await pool.query(
        `SELECT * FROM transferencia_interbancaria WHERE transfer_id_ws = $1`,
        [transferId],
      );

      if (transferResult.rows.length === 0) {
        console.error(`[WebSocket] Transferencia no encontrada: ${transferId}`);
        this.socket.emit('transfer.debit.result', {
          id: transferId,
          ok: false,
          reason: 'TRANSFER_NOT_FOUND',
        });
        return;
      }

      const transfer = transferResult.rows[0];

      // Obtener cuenta origen
      const cuentaResult = await pool.query(
        `SELECT * FROM cuenta WHERE id = $1`,
        [transfer.cuenta_origen_id],
      );

      const cuenta = cuentaResult.rows[0];

      // Crear movimiento de débito
      const movimientoResult = await pool.query(
        `INSERT INTO movimientoCuenta 
         (cuenta_id, fecha, tipo, descripcion, moneda, monto, referencia)
         VALUES ($1, NOW(), 
                 (SELECT id FROM tipoMovimientoCuenta WHERE nombre = 'Débito'),
                 $2,
                 $3,
                 $4,
                 $5)
         RETURNING id`,
        [
          cuenta.id,
          `Transferencia interbancaria enviada - ${transfer.descripcion || ''}`,
          transfer.moneda,
          transfer.monto,
          `WS-${transferId}`,
        ],
      );

      // Actualizar saldo de cuenta
      await pool.query(
        `UPDATE cuenta SET saldo = saldo - $1 WHERE id = $2`,
        [transfer.monto, cuenta.id],
      );

      // Liberar reserva
      await pool.query(
        `UPDATE transferencia_reserva SET estado = 'released' WHERE transfer_id_ws = $1`,
        [transferId],
      );

      // Vincular movimiento con transferencia
      await pool.query(
        `UPDATE transferencia_interbancaria SET movimiento_debito_id = $1 WHERE transfer_id_ws = $2`,
        [movimientoResult.rows[0].id, transferId],
      );

      console.log(`[WebSocket] Debito realizado exitosamente (Movimiento ID: ${movimientoResult.rows[0].id})`);

      // Responder éxito
      this.socket.emit('transfer.debit.result', {
        id: transferId,
        ok: true,
      });

      await this.logEvent(transferId, 'transfer.debit.result', { ok: true }, 
                        transfer.banco_origen, transfer.banco_destino, 'sent');

    } catch (error) {
      console.error('[WebSocket] Error en handleDebit:', error);
      this.socket.emit('transfer.debit.result', {
        id: transferId,
        ok: false,
        reason: 'DEBIT_FAILED',
      });
    }
  }

  async handleCommit(data) {
    console.log('[WebSocket] Evento recibido: transfer.commit');
    console.log('[WebSocket] Data:', JSON.stringify(data, null, 2));

    const { id: transferId } = data;

    try {
      // Actualizar estado de transferencia a completado
      await pool.query(
        `UPDATE transferencia_interbancaria 
         SET estado = 'completed', fecha_completado = NOW() 
         WHERE transfer_id_ws = $1`,
        [transferId],
      );

      // Si hay cuenta destino en este banco, actualizar saldo
      const cuentaDestino = await pool.query(
        `SELECT c.* FROM cuenta c
         INNER JOIN transferencia_interbancaria t ON c.iban = t.cuenta_destino_iban
         WHERE t.transfer_id_ws = $1`,
        [transferId],
      );

      if (cuentaDestino.rows.length > 0) {
        const transfer = await pool.query(
          `SELECT * FROM transferencia_interbancaria WHERE transfer_id_ws = $1`,
          [transferId],
        );
        
        await pool.query(
          `UPDATE cuenta SET saldo = saldo + $1 WHERE id = $2`,
          [transfer.rows[0].monto, cuentaDestino.rows[0].id],
        );
        
        console.log('[WebSocket] Saldo de cuenta destino actualizado');
      }

      console.log('[WebSocket] Transferencia completada exitosamente');

      const fromBank = data.from ? data.from.substring(4, 7) : null;
      const toBank = data.to ? data.to.substring(4, 7) : null;
      await this.logEvent(transferId, 'transfer.commit', data, fromBank, toBank, 'received');

      // Resolver promesa pendiente
      const pending = this.pendingTransfers.get(transferId);
      if (pending) {
        clearTimeout(pending.timeout);
        pending.resolve({
          success: true,
          transferId: transferId,
          message: 'Transferencia interbancaria completada exitosamente',
        });
        this.pendingTransfers.delete(transferId);
      }

    } catch (error) {
      console.error('[WebSocket] Error en handleCommit:', error);
    }
  }

  async handleRollback(data) {
    console.log('[WebSocket] Evento recibido: transfer.rollback');
    console.log('[WebSocket] Data:', JSON.stringify(data, null, 2));

    const { id: transferId, reason } = data;

    try {
      // Liberar reserva si existe
      await pool.query(
        `UPDATE transferencia_reserva SET estado = 'released' WHERE transfer_id_ws = $1`,
        [transferId],
      );

      // Actualizar estado de transferencia
      await pool.query(
        `UPDATE transferencia_interbancaria 
         SET estado = 'reversed', notas = $1 
         WHERE transfer_id_ws = $2`,
        [reason || 'Rollback por el Banco Central', transferId],
      );

      // Eliminar movimientos temporales si existen
      await pool.query(
        `DELETE FROM movimientoCuenta WHERE referencia = $1`,
        [`WS-${transferId}`],
      );

      console.log('[WebSocket] Rollback procesado exitosamente');

      const fromBank = data.from ? data.from.substring(4, 7) : null;
      const toBank = data.to ? data.to.substring(4, 7) : null;
      await this.logEvent(transferId, 'transfer.rollback', data, fromBank, toBank, 'received');

      // Rechazar promesa pendiente
      const pending = this.pendingTransfers.get(transferId);
      if (pending) {
        clearTimeout(pending.timeout);
        pending.reject({
          success: false,
          code: 'ROLLBACK',
          message: `Transferencia revertida: ${reason || 'Error en el proceso'}`,
        });
        this.pendingTransfers.delete(transferId);
      }

    } catch (error) {
      console.error('[WebSocket] Error en handleRollback:', error);
    }
  }

  async handleReject(data) {
    console.log('[WebSocket] Evento recibido: transfer.reject');
    console.log('[WebSocket] Data:', JSON.stringify(data, null, 2));

    const { id: transferId, reason } = data;

    try {
      // Liberar reserva si existe
      await pool.query(
        `UPDATE transferencia_reserva SET estado = 'released' WHERE transfer_id_ws = $1`,
        [transferId],
      );

      // Actualizar estado de transferencia
      await pool.query(
        `UPDATE transferencia_interbancaria 
         SET estado = 'failed', notas = $1 
         WHERE transfer_id_ws = $2`,
        [reason || 'Rechazada por el Banco Central', transferId],
      );

      console.log('[WebSocket] Rechazo procesado exitosamente');

      const fromBank = data.from ? data.from.substring(4, 7) : null;
      const toBank = data.to ? data.to.substring(4, 7) : null;
      await this.logEvent(transferId, 'transfer.reject', data, fromBank, toBank, 'received');

      // Rechazar promesa pendiente
      const pending = this.pendingTransfers.get(transferId);
      if (pending) {
        clearTimeout(pending.timeout);
        pending.reject({
          success: false,
          code: reason || 'REJECTED',
          message: this.getErrorMessage(reason),
        });
        this.pendingTransfers.delete(transferId);
      }

    } catch (error) {
      console.error('[WebSocket] Error en handleReject:', error);
    }
  }

  // ============================================
  // UTILIDADES
  // ============================================

  async logEvent(transferId, eventType, eventData, fromBank, toBank, estado) {
    try {
      await pool.query(
        `INSERT INTO ws_eventos 
         (transfer_id, evento_tipo, evento_data, banco_origen, banco_destino, estado)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [transferId, eventType, JSON.stringify(eventData), fromBank, toBank, estado],
      );
    } catch (error) {
      console.error('[WebSocket] Error al registrar evento:', error);
    }
  }

  getErrorMessage(reason) {
    const messages = {
      'NO_FUNDS': 'Fondos insuficientes en la cuenta origen',
      'ACCOUNT_NOT_FOUND': 'La cuenta destino no existe',
      'DEST_BANK_OFFLINE': 'El banco destino no está disponible',
      'TIMEOUT': 'La operación tardó demasiado tiempo',
      'SAME_BANK': 'Use transferencia interna para cuentas del mismo banco',
      'INVALID_ACCOUNT': 'Cuenta inválida',
      'CREDIT_FAILED': 'Error al acreditar fondos',
      'DEBIT_FAILED': 'Error al debitar fondos',
      'INTERNAL_ERROR': 'Error interno del sistema',
    };

    return messages[reason] || 'Error desconocido en la transferencia';
  }
}

// Singleton instance
let wsManagerInstance = null;

function getWebSocketManager() {
  if (!wsManagerInstance) {
    wsManagerInstance = new WebSocketManager();
    wsManagerInstance.connect();
  }
  return wsManagerInstance;
}

module.exports = {
  getWebSocketManager,
  WebSocketManager,
};
