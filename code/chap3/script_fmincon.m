clc;
clear;
format long;

% fileID = fopen('output.txt','w');

A = [
    0.921, 0, 0.041, 0;
    0, 0.918, 0, 0.033;
    0, 0, 0.924, 0;
    0, 0, 0, 0.937
];
 B = [
    0.017, 0.001;
    0.001, 0.023;
    0, 0.061;
    0.072, 0;
];
 C = [
    1,0,0,0; 
    0,1,0,0
];
 D = zeros(2, 2);
 N = 400;
 uSteady = [1; 1];
 ySteady = [0.65; 0.77];
 L = 30;
 n = 4;
 m = 2;
 p = 2;
 R = 10^-4 * eye(2);
 Q = 3 * eye(2);
 lambdaSigma=1000;
 lambdaAlphaEps=0.1;
 epsilon=0.002;
 normValue = @(x, matrix) sqrt(x * matrix * x');
 l = @(u, y) normValue(u, R)^2 + normValue(y, Q)^2;

alphaShift = (L + n) * 4;
alphaRange = alphaShift + 1:(L + n) * 4 + N - (L + n) + 1;
sigmaShift = alphaRange(end);
sigmaRange = sigmaShift + 1:(L + n) * 4 + N - (L + n) + 1 + (L + n) * 2;

objective = @(x) objectiveFunc(x, n, L, l, uSteady, ySteady, sigmaRange, alphaRange, lambdaAlphaEps, lambdaSigma);

% {u^d, y^d}.
uData = zeros(1, N * 2);
yData = zeros(1, N * 2);
curX = zeros(1, 4)';

for i = 1:N
    uData(1, [i * 2 - 1 i * 2]) = [ - 1 + 2 / N * (i - 1)];
    %uData(1, [i * 2 - 1 i * 2]) = [-1 + rand * 2 -1 + rand * 2];
    yData(1, [i * 2 - 1 i * 2]) = [(C * curX)];
    curX = A * curX + B * uData(1, [i * 2 - 1 i * 2])';
end

uRes = zeros(N + n, 2);
yRes = zeros(N + n, 2);
xRes = zeros(N + n, 4);

Aeq = zeros((L + n) * 4, (L + n) * 4 + N - (L + n) + 1 + (L + n) * 2);
beq = zeros(1, (L + n) * 4);
uHankel = hankelMatrix(reshape(uData, 2, N)', L + n, N);
yHankel = hankelMatrix(reshape(yData, 2, N)', L + n, N);

sigmaIndex = 1;

for i = 1:4:(L + n) * 4
    Aeq(i, i) = 1;
    Aeq(i + 1, i + 1) = 1;
    Aeq(i + 2, i + 2) = 1;
    Aeq(i + 3, i + 3) = 1;
    Aeq(i + 2, sigmaShift + sigmaIndex) = 1;
    Aeq(i + 3, sigmaShift + sigmaIndex + 1) = 1;
    
    sigmaIndex = sigmaIndex + 2;
    
    hIndex = fix(i / 4) + 1;
    Aeq(i, alphaRange) = -uHankel(hIndex, :, 1);
    Aeq(i + 1, alphaRange) = -uHankel(hIndex, :, 2);
    Aeq(i + 2, alphaRange) = -yHankel(hIndex, :, 1);
    Aeq(i + 3, alphaRange) = -yHankel(hIndex, :, 2);
end


curX = zeros(1, 4);
disp('MPC loop started.');
for t = 0:N
    disp('iteration');
    disp(t);
    
    % Main constraint.
    timeIndex = n + 1 + t;
    Aeq(1:n * 4, alphaRange) = zeros(n * 4, N - (L + n) + 1);
    j = t + 1;
    
    for i = 1:4:L * 4
        Aeq(i + 2, sigmaRange) = 0;
        Aeq(i + 3, sigmaRange) = 0;
        Aeq(i, alphaRange) = 0;
        Aeq(i + 1, alphaRange) = 0;
        Aeq(i + 2, alphaRange) = 0;
        Aeq(i + 3, alphaRange) = 0;
        
        beq(i) = uRes(j, 1);
        beq(i + 1) = uRes(j, 2);
        beq(i + 2) = yRes(j, 1);
        beq(i + 3) = yRes(j, 2);
        j = j + 1;
   end
    
    % Terminal constraint.
    for i = L * 4 + 1:4:(L + n) * 4
        Aeq(i + 2, sigmaRange) = 0;
        Aeq(i + 3, sigmaRange) = 0;
        Aeq(i, alphaRange) = 0;
        Aeq(i + 1, alphaRange) = 0;
        Aeq(i + 2, alphaRange) = 0;
        Aeq(i + 3, alphaRange) = 0;
        beq(i) = uSteady(1, 1);
        beq(i + 1) = uSteady(2, 1);
        beq(i + 2) = ySteady(1, 1);
        beq(i + 3) = ySteady(2, 1);
    end
    
    startedValues = [ ...
        beq(1:4 * n) ...
        zeros(1, (L + n) * 4 - 4 * n - 4 * n) ...
        beq((L + n) * 4 - n * 4 + 1:(L + n) * 4) ...
        zeros(1, N - (L + n) + 1) ...
        zeros(1, (L + n) * 2)
    ];

    % ? ?????? ?????????? ?? ???????? ??????????? ? ????????????, ??? ???
    % ???????????.
    %[res, value] = fmincon(objective, startedValues, [], [], Aeq, beq',[],[]); 
    % -----
    
    % ? ?????????????
    [res, value] = fmincon(objective, startedValues, [], [], Aeq, beq',[],[], @nonlinconfunc);
    
    
    res = res(1:(L + n) * 4);
    j = timeIndex - n;
    for i = 1:4:(L + n) * 4
        uRes(j, 1) = res(i);
        uRes(j, 2) = res(i + 1);
        [dsResY, dsResX] = dynamicSystemFunc(uRes(j,:)', xRes(j,:)', A, B, C);
%           yRes(j, 1) = res(i + 2);
%           yRes(j, 2) = res(i + 3);
         yRes(j,:) = dsResY;
        j = j + 1;
        xRes(j,:) = dsResX';
    end
    
    disp(uRes(j - 1 , :));
    disp(value);
%      i = n * 4 + 1;
%     uRes(j, 1) = res(i);
%     uRes(j, 2) = res(i + 1);
%     yRes(j, 1) = res(i + 2);
%     yRes(j, 2) = res(i + 3);
%         newY = C * curX';
%         yRes(j, 1) = newY(1);
%         yRes(j, 2) = newY(2);
    %disp(res); 
end
hold off;

hold on;
plot(yRes(30:end, 1));
plot(ones(N + 10, 1) * (ySteady(1)))
plot(yRes(30:end, 2));
plot(ones(N + 10, 1) * (ySteady(2)))
ylim([0, 1.2]);
xlim([0,N+10]);
hold off;


%fclose(fileID);