import { ble } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG: string = 'BleAdvertisingManager';

export class BleAdvertisingManager {
  private advHandle: number = 0xFF; // Initial invalid value.

  // 1. Define the BLE advertising status reporting event.
  onReceiveEvent = (data: ble.AdvertisingStateChangeInfo) => {
    AppStorage.setOrCreate('advertiserState', data.state);
  };

  // 2. Start BLE advertising for the first time.
  public async startAdvertising() {
    // 2.1 Set BLE advertising parameters.
    let setting: ble.AdvertiseSetting = {
      interval: 160,
      txPower: 0,
      connectable: true
    };
    // 2.2 Construct the data to be advertised.
    let manufactureValueBuffer = new Uint8Array(4);
    manufactureValueBuffer[0] = 1;
    manufactureValueBuffer[1] = 2;
    manufactureValueBuffer[2] = 3;
    manufactureValueBuffer[3] = 4;
    let serviceValueBuffer = new Uint8Array(4);
    serviceValueBuffer[0] = 5;
    serviceValueBuffer[1] = 6;
    serviceValueBuffer[2] = 7;
    serviceValueBuffer[3] = 8;
    let manufactureDataUnit: ble.ManufactureData = {
      manufactureId: 4567,
      manufactureValue: manufactureValueBuffer.buffer
    };
    let serviceDataUnit1: ble.ServiceData = {
      serviceUuid: '00001999-0000-1000-8000-00805f9b34fb',
      serviceValue: serviceValueBuffer.buffer
    };
    let serviceDataUnit2: ble.ServiceData = {
      serviceUuid: '19991999-0000-1000-8000-00805f9b34fb',
      serviceValue: serviceValueBuffer.buffer
    };
    let advData: ble.AdvertiseData = {
      serviceUuids: ['00001888-0000-1000-8000-00805f9b34fb', '18881888-0000-1000-8000-00805f9b34fb'],
      manufactureData: [manufactureDataUnit],
      serviceData: [],
      includeDeviceName: false // Whether the device name is contained.
      // This parameter is optional. Note that the BLE
      // advertising will fail if the maximum length (31 bytes) is exceeded.
    };
    let advResponse: ble.AdvertiseData = {
      serviceUuids: [],
      manufactureData: [],
      serviceData: [serviceDataUnit1, serviceDataUnit2]
    };
    // 2.3 Construct AdvertisingParams for starting the BLE advertising.
    let advertisingParams: ble.AdvertisingParams = {
      advertisingSettings: setting,
      advertisingData: advData, // The length of advertising packets cannot exceed 31 bytes.
      advertisingResponse: advResponse, // The length of advertising packets cannot exceed 31 bytes.
      duration: 0 // Advertising duration.
      // This parameter is optional. If the value is greater than 0,
      // advertising will stop after the specified duration elapses,
      // but the allocated advertising resources will remain. You can start advertising again as needed.
    }

    // 2.4 During initial advertising, the Bluetooth subsystem automatically allocates relevant resources,
    // including the BLE advertising ID obtained by the application.
    try {
      ble.on('advertisingStateChange', this.onReceiveEvent);
      this.advHandle = await ble.startAdvertising(advertisingParams);
    } catch (err) {
      console.error(TAG, 'errCode: ' + (err as BusinessError).code + ', errMessage: ' + (err as BusinessError).message);
    }
  }

  // 3. Disable the BLE advertising with the specified ID, that is, the ID allocated during initial advertising.
  // The allocated advertising resources will remain after the BLE advertising is disabled.
  public async disableAdvertising() {
    // 3.1 Construct an advertisingDisableParams instance for disabling BLE advertising.
    let advertisingDisableParams: ble.AdvertisingDisableParams = {
      advertisingId: this.advHandle // Use the ID of the first BLE advertising.
    }
    try {
      // 3.2 Disable the BLE advertising.
      await ble.disableAdvertising(advertisingDisableParams);
    } catch (err) {
      console.error(TAG, 'errCode: ' + (err as BusinessError).code + ', errMessage: ' + (err as BusinessError).message);
    }
  }

  // 4. Enable the BLE advertising with the specified ID, that is, the ID allocated during initial advertising
  public async enableAdvertising(enableDuration: number) {
    // 4.1 Construct an advertisingEnableParams instance for enabling BLE advertising.
    let advertisingEnableParams: ble.AdvertisingEnableParams = {
      advertisingId: this.advHandle, // Use the ID of the first BLE advertising.
      duration: enableDuration
    }
    try {
      // 4.2 Enable BLE advertising again.
      await ble.enableAdvertising(advertisingEnableParams);
    } catch (err) {
      console.error(TAG, 'errCode: ' + (err as BusinessError).code + ', errMessage: ' + (err as BusinessError).message);
    }
  }

  // 5. Stop BLE advertising to release related resources.
  public async stopAdvertising() {
    try {
      await ble.stopAdvertising(this.advHandle);
      ble.off('advertisingStateChange', this.onReceiveEvent);
    } catch (err) {
      console.error(TAG, 'errCode: ' + (err as BusinessError).code + ', errMessage: ' + (err as BusinessError).message);
    }
  }
}

let bleAdvertisingManager = new BleAdvertisingManager();
export default bleAdvertisingManager as BleAdvertisingManager;