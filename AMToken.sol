// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

contract AcademicMeritToken {
    // ========== Информация о токене ==========
    string public name = "Academic Merit Token";
    string public symbol = "AMT";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    // ========== Стандартные ERC-20 маппинги ==========
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    // ========== Данные для рейтинга студентов ==========
    struct StudentInfo {
        uint256 points;
        uint256 lastSemesterTimestamp;
        uint256 publicationsCount;
        uint256 olympiadWinsCount;
        bool isActive;
    }
    
    mapping(address => StudentInfo) public students;
    address[] public activeStudents;
    
    // ========== Администрирование ==========
    address public admin;
    mapping(address => bool) public verifiers; // Верификаторы (научный отдел, деканат)
    
    // ========== Привилегии ==========
    enum Privilege { 
        EarlySession,      // выбор удобного времени сессии
        ResearchAccess,    // доступ к закрытым научным ресурсам
        PriorityEnrollment // внеочередная запись на популярные курсы
    }
    
    mapping(Privilege => uint256) public privilegeCost;
    mapping(address => mapping(Privilege => bool)) public redeemedPrivileges;
    
    // ========== События ==========
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Awarded(address indexed student, uint256 amount, string reason, uint8 awardType);
    event Redeemed(address indexed student, uint256 privilegeId, string privilegeName);
    event VerifierAdded(address indexed verifier);
    event VerifierRemoved(address indexed verifier);
    
    // ========== Модификаторы ==========
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this");
        _;
    }
    
    modifier onlyVerifier() {
        require(verifiers[msg.sender], "Only verifier can call this");
        _;
    }
    
    // ========== Конструктор ==========
    constructor() {
        admin = msg.sender;
        verifiers[msg.sender] = true;
        
        // Инициализация стоимости привилегий
        privilegeCost[Privilege.EarlySession] = 300 * 10**18;      // 300 AMT
        privilegeCost[Privilege.ResearchAccess] = 150 * 10**18;    // 150 AMT
        privilegeCost[Privilege.PriorityEnrollment] = 250 * 10**18; // 250 AMT
    }
    
    // ========== Администрирование ==========
    function addVerifier(address _verifier) public onlyAdmin {
        require(!verifiers[_verifier], "Already a verifier");
        verifiers[_verifier] = true;
        emit VerifierAdded(_verifier);
    }
    
    function removeVerifier(address _verifier) public onlyAdmin {
        require(verifiers[_verifier], "Not a verifier");
        require(_verifier != admin, "Cannot remove admin");
        verifiers[_verifier] = false;
        emit VerifierRemoved(_verifier);
    }
    
    // ========== Начисление токенов ==========
    
    // За сессию без троек: +50 AMT
    function awardForGrade(address student, string memory semester) public onlyVerifier {
        require(student != address(0), "Invalid address");
        
        // Проверка, что начисление за этот семестр еще не было
        // В реальной системе здесь была бы интеграция с университетской системой
        uint256 amount = 50 * 10**18;
        
        _mint(student, amount);
        emit Awarded(student, amount, semester, 1);
    }
    
    // За победу в олимпиаде: +100 AMT
    function awardForOlympiad(address student, string memory olympiadName) public onlyVerifier {
        require(student != address(0), "Invalid address");
        
        uint256 amount = 100 * 10**18;
        
        _mint(student, amount);
        
        // Обновляем информацию о студенте
        if (!students[student].isActive) {
            students[student].isActive = true;
            activeStudents.push(student);
        }
        students[student].olympiadWinsCount++;
        
        emit Awarded(student, amount, olympiadName, 2);
    }
    
    // За публикацию статьи: +200 AMT
    function awardForPublication(address student, string memory publicationTitle) public onlyVerifier {
        require(student != address(0), "Invalid address");
        
        uint256 amount = 200 * 10**18;
        
        _mint(student, amount);
        
        // Обновляем информацию о студенте
        if (!students[student].isActive) {
            students[student].isActive = true;
            activeStudents.push(student);
        }
        students[student].publicationsCount++;
        
        emit Awarded(student, amount, publicationTitle, 3);
    }
    
    // ========== Обмен на привилегии ==========
    
    function redeemPrivilege(uint256 privilegeId) public {
        require(privilegeId <= 2, "Invalid privilege ID");
        Privilege privilege = Privilege(privilegeId);
        
        uint256 cost = privilegeCost[privilege];
        require(balanceOf[msg.sender] >= cost, "Insufficient balance");
        require(!redeemedPrivileges[msg.sender][privilege], "Already redeemed this privilege");
        
        // Сжигаем токены
        balanceOf[msg.sender] -= cost;
        totalSupply -= cost;
        
        // Отмечаем, что привилегия использована
        redeemedPrivileges[msg.sender][privilege] = true;
        
        string memory privilegeName;
        if (privilegeId == 0) privilegeName = "Early Session Selection";
        else if (privilegeId == 1) privilegeName = "Research Access";
        else privilegeName = "Priority Enrollment";
        
        emit Redeemed(msg.sender, privilegeId, privilegeName);
    }
    
    function getPrivilegeCost(uint256 privilegeId) public view returns (uint256) {
        require(privilegeId <= 2, "Invalid privilege ID");
        return privilegeCost[Privilege(privilegeId)];
    }
    
    function hasRedeemedPrivilege(address student, uint256 privilegeId) public view returns (bool) {
        require(privilegeId <= 2, "Invalid privilege ID");
        return redeemedPrivileges[student][Privilege(privilegeId)];
    }
    
    // ========== Рейтинг студентов ==========
    
    function getRanking() public view returns (address[] memory, uint256[] memory) {
        // Создаем временный массив для сортировки
        uint256 activeCount = activeStudents.length;
        
        // Ограничиваем топ-10
        uint256 topCount = activeCount < 10 ? activeCount : 10;
        
        address[] memory topAddresses = new address[](topCount);
        uint256[] memory topPoints = new uint256[](topCount);
        
        // Собираем всех активных студентов с их баллами
        address[] memory tempAddresses = new address[](activeCount);
        uint256[] memory tempPoints = new uint256[](activeCount);
        
        for (uint256 i = 0; i < activeCount; i++) {
            tempAddresses[i] = activeStudents[i];
            tempPoints[i] = balanceOf[activeStudents[i]];
        }
        
        // Пузырьковая сортировка по убыванию баллов
        for (uint256 i = 0; i < activeCount - 1; i++) {
            for (uint256 j = 0; j < activeCount - i - 1; j++) {
                if (tempPoints[j] < tempPoints[j + 1]) {
                    // Меняем баллы
                    uint256 tempPoint = tempPoints[j];
                    tempPoints[j] = tempPoints[j + 1];
                    tempPoints[j + 1] = tempPoint;
                    
                    // Меняем адреса
                    address tempAddress = tempAddresses[j];
                    tempAddresses[j] = tempAddresses[j + 1];
                    tempAddresses[j + 1] = tempAddress;
                }
            }
        }
        
        // Берем топ-N
        for (uint256 i = 0; i < topCount; i++) {
            topAddresses[i] = tempAddresses[i];
            topPoints[i] = tempPoints[i];
        }
        
        return (topAddresses, topPoints);
    }
    
    function getStudentStats(address student) public view returns (
        uint256 points,
        uint256 publications,
        uint256 olympiadWins,
        bool isActive
    ) {
        return (
            balanceOf[student],
            students[student].publicationsCount,
            students[student].olympiadWinsCount,
            students[student].isActive
        );
    }
    
    // ========== ERC-20 стандартные методы ==========
    
    function transfer(address to, uint256 value) public returns (bool success) {
        require(to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function approve(address spender, uint256 value) public returns (bool success) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        require(to != address(0), "Invalid address");
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Not allowed");
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        
        emit Transfer(from, to, value);
        return true;
    }
    
    // ========== Внутренние функции ==========
    
    function _mint(address to, uint256 amount) internal {
        balanceOf[to] += amount;
        totalSupply += amount;
        
        emit Transfer(address(0), to, amount);
    }
}
