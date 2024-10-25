// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {MyTokenB} from "../src/MyTokenB.sol";
import "forge-std/console.sol";

contract DeployTokenB is Script {
    function run() external {
        // Configurar el remitente (sender) desde una variable de entorno
        // Cargar la clave privada desde variables de entorno o en el script
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TOKEN_B");

        // Iniciar broadcast para que Foundry capture las transacciones
        vm.startBroadcast(deployerPrivateKey);

        // Desplegar el primer contrato
        MyTokenB contract1 = new MyTokenB(type(uint256).max);

        // Detener el broadcast para que Foundry deje de capturar
        vm.stopBroadcast();

        // Opción: Mostrar la dirección del contrato desplegado
        console.log("Contrato desplegado en:", address(contract1));
    }
}
