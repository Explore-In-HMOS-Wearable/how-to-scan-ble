import { ble } from '@kit.ConnectivityKit';
import bleAdvertisingManager from '../utils/BleAdvertising';
import bleScanManager from '../utils/BleScanning';
import { requestPermission } from '../utils/RequestPermission';
import { common } from '@kit.AbilityKit';

interface ScanResultDisplay {
  deviceId: string;
  txPowerLevel: number;
  localName: string;
  manufactureSpecificData: string;
  timestamp: number;
}

@Entry
@Component
struct Index {
  @State advertiseStatus: ble.AdvertisingState = ble.AdvertisingState.STOPPED;
  @State advertiseStatusText: ResourceStr = $r('app.string.advertiseStatusText');
  @State isScanning: boolean = false;
  @State scanResultText: ResourceStr = $r('app.string.scanResultText');
  private uiContext = this.getUIContext();

  @State scanResults: ScanResultDisplay[] = [];
  onReceiveScanEvent = (scanReport: ble.ScanReport) => {
    if (scanReport.scanResult.length > 0) {
      const firstResult = scanReport.scanResult[0];
      const resultData = firstResult.data;

      let tempAdvData = new Uint8Array(resultData);
      let tempCurPos = 0;
      let tempManufactureSpecificData: string = '';

      while (tempCurPos < tempAdvData.byteLength) {
        let length = tempAdvData[tempCurPos++];
        if (length === 0) {
          break;
        }
        let advDataLength = length - 1;
        let advDataType = tempAdvData[tempCurPos++];

        const BLE_ADV_TYPE_MANUFACTURER_SPECIFIC_DATA = 0xFF;

        if (advDataType === BLE_ADV_TYPE_MANUFACTURER_SPECIFIC_DATA) {
          const manufactureId = (tempAdvData[tempCurPos + 1] << 8) + tempAdvData[tempCurPos];
          const data = tempAdvData.slice(tempCurPos + 2, tempCurPos + advDataLength);
          tempManufactureSpecificData = `ID: ${manufactureId}, Data: [${Array.from(data).join(',')}]`;
          break;
        }
        tempCurPos += advDataLength;
      }

      const newResult: ScanResultDisplay = {
        deviceId: firstResult.deviceId,
        txPowerLevel: firstResult.rssi,
        localName: firstResult.deviceName,
        manufactureSpecificData: tempManufactureSpecificData,
        timestamp: Date.now()
      };

      this.scanResults.unshift(newResult);
      if (this.scanResults.length > 5) {
        this.scanResults = this.scanResults.slice(0, 5);
      }
      this.updateScanResultsDisplay();
    }
  };

  updateScanResultsDisplay() {
    if (this.scanResults.length === 0) {
      this.scanResultText = $r('app.string.scanResultTextNotFound');
      return;
    }
    this.scanResultText = 'Scan Results (Last 5):\n' + this.scanResults.map((res, index) =>
    `  #${index + 1}: ${res.deviceId.substring(0, 15)}...\n` +
      `    Name: ${res.localName || 'N/A'}\n` +
      `    Tx Power: ${res.txPowerLevel} dBm\n` +
      `    Mfg Data: ${res.manufactureSpecificData || 'N/A'}`
    ).join('\n---\n');
  }

  onReceiveAdvertiseEvent = (data: ble.AdvertisingStateChangeInfo) => {
    this.advertiseStatus = data.state;
    this.advertiseStatusText = `Advertising Status: ${this.getAdvertiseStateString(data.state)}`;
    AppStorage.setOrCreate('advertiserState', data.state);
  };

  getAdvertiseStateString(state: ble.AdvertisingState): string {
    switch (state) {
      case ble.AdvertisingState.STARTED:
        return 'STARTED';
      case ble.AdvertisingState.STOPPED:
        return 'STOPPED';
      case ble.AdvertisingState.DISABLED:
        return 'FAILED';
      default:
        return 'UNKNOWN';
    }
  }

  async aboutToAppear() {
    const realContext = this.uiContext.getHostContext();
    await requestPermission(['ohos.permission.ACCESS_BLUETOOTH'], realContext as common.UIAbilityContext);

    bleAdvertisingManager.onReceiveEvent = this.onReceiveAdvertiseEvent;


    bleScanManager.bleScanner.off('BLEDeviceFind', bleScanManager.onReceiveEvent);
    bleScanManager.onReceiveEvent = this.onReceiveScanEvent;
  }

  aboutToDisappear() {
    bleAdvertisingManager.onReceiveEvent = (data) => {
      AppStorage.setOrCreate('advertiserState', data.state);
    };
    bleScanManager.onReceiveEvent = (scanReport: ble.ScanReport) => {
      if (scanReport.scanResult.length > 0) {
        bleScanManager.parseScanResult(scanReport.scanResult[0].data);
      }
    };
  }

  build() {
    Scroll() {
      Column() {
        Text($r('app.string.advertising_control'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 10, bottom: 5 })

        Row() {
          Button($r('app.string.startAdv'))
            .width('48%')
            .onClick(() => {
              bleAdvertisingManager.startAdvertising();
            })

          Button($r('app.string.stopAdv'))
            .width('48%')
            .backgroundColor(Color.Red)
            .onClick(() => {
              bleAdvertisingManager.stopAdvertising();
            })
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .width('90%')
        .margin({ bottom: 10 })

        Text(this.advertiseStatusText)
          .fontSize(14)
          .fontColor(this.advertiseStatus === ble.AdvertisingState.STARTED ? Color.Green : Color.White)
          .margin({ bottom: 20 })

        Divider()

        Text($r('app.string.scanning_control'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 10, bottom: 5 })

        Row() {
          Button(this.isScanning ? $r('app.string.buttonStopScan') : $r('app.string.buttonStartScan'))
            .width('48%')
            .backgroundColor(this.isScanning ? Color.Red : Color.Blue)
            .onClick(() => {
              if (this.isScanning) {
                bleScanManager.stopScan();
                this.isScanning = false;
                this.scanResultText = $r('app.string.scanResultTextScanStopped');
              } else {
                this.scanResults = [];
                this.updateScanResultsDisplay();
                bleScanManager.startScan();
                this.isScanning = true;
                this.scanResultText = $r('app.string.scanResultTextScanning');
              }
            })
        }
        .justifyContent(FlexAlign.Start)
        .width('90%')
        .margin({ bottom: 10 })

        Text(this.isScanning ? 'Scanning: ON' : 'Scanning: OFF')
          .fontSize(14)
          .fontColor(this.isScanning ? Color.Green : Color.White)
          .margin({ bottom: 10 })
        Text(this.scanResultText)
          .fontSize(12)
          .textAlign(TextAlign.Start)
          .width('100%')
          .padding(5)
          .backgroundColor(Color.Gray)
          .borderRadius(8)
      }
      .width('100%')
      .height('100%')
      .padding(15)
    }
    .height(500)
    .width('100%')
    .alignSelf(ItemAlign.Center)
  }
}