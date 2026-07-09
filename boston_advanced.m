%% ================================================================
%  Boston Housing - Polynomial Features + Ridge + Lasso Regression
%  Target: MEDV (median house value, unit: $1000)
%  Features: 13 raw -> 104 polynomial (degree=2)
%% ================================================================
clear; clc; close all;

%% -- 1. Load Data --
[fname, fpath] = uigetfile('*.csv', 'Select boston.csv');
if isequal(fname, 0)
    error('No file selected.');
end
data = readtable(fullfile(fpath, fname));

feature_names = {'CRIM','ZN','INDUS','CHAS','NOX','RM', ...
                 'AGE','DIS','RAD','TAX','PTRATIO','B','LSTAT'};

X_raw = table2array(data(:, feature_names));
y     = table2array(data(:, 'MEDV'));
fprintf('Dataset: %d rows x %d cols\n', size(X_raw,1), size(X_raw,2));

%% -- 2. Z-score Normalization --
mu    = mean(X_raw);
sigma = std(X_raw);
X_norm = (X_raw - mu) ./ sigma;

%% -- 3. Polynomial Features (degree = 2) --
% Expands 13 features -> 104 features (linear + squared + interactions)
X_poly = poly_features(X_norm);
fprintf('After polynomial expansion: %d features\n', size(X_poly, 2));

% Normalize polynomial features
mu_poly    = mean(X_poly);
sigma_poly = std(X_poly);
sigma_poly(sigma_poly == 0) = 1;  % avoid division by zero
X_poly_norm = (X_poly - mu_poly) ./ sigma_poly;

%% -- 4. Train / Test Split (80% / 20%) --
rng(42);
m = size(X_poly_norm, 1);
idx = randperm(m);
train_size = round(0.8 * m);

X_train = X_poly_norm(idx(1:train_size), :);
y_train = y(idx(1:train_size));
X_test  = X_poly_norm(idx(train_size+1:end), :);
y_test  = y(idx(train_size+1:end));

% Add bias column
X_train_b = [ones(size(X_train,1),1), X_train];
X_test_b  = [ones(size(X_test,1),1),  X_test];
n = size(X_train_b, 2);
m_train = size(X_train_b, 1);

%% -- 5. Baseline: Gradient Descent (plain linear regression) --
fprintf('\n[1] Baseline: Gradient Descent...\n');
alpha_gd  = 0.05;
iter_gd   = 1000;
theta_gd  = zeros(n, 1);
cost_gd   = zeros(iter_gd, 1);

for it = 1:iter_gd
    err       = X_train_b * theta_gd - y_train;
    cost_gd(it) = sum(err.^2) / (2*m_train);
    theta_gd  = theta_gd - (alpha_gd/m_train) * (X_train_b' * err);
end

[r2_gd_tr, rmse_gd_tr] = eval_model(X_train_b, y_train, theta_gd);
[r2_gd_te, rmse_gd_te] = eval_model(X_test_b,  y_test,  theta_gd);
fprintf('   Train R2=%.4f  Test R2=%.4f  RMSE=%.4f\n', r2_gd_tr, r2_gd_te, rmse_gd_te);

%% -- 6. Ridge Regression (L2 penalty, closed-form solution) --
% theta = (X^T X + lambda*I)^{-1} X^T y
fprintf('\n[2] Ridge Regression (lambda=1)...\n');
lambda_ridge = 1.0;
I_reg = eye(n);
I_reg(1,1) = 0;  % do not penalize bias term
theta_ridge = (X_train_b' * X_train_b + lambda_ridge * I_reg) \ (X_train_b' * y_train);

[r2_ridge_tr, rmse_ridge_tr] = eval_model(X_train_b, y_train, theta_ridge);
[r2_ridge_te, rmse_ridge_te] = eval_model(X_test_b,  y_test,  theta_ridge);
fprintf('   Train R2=%.4f  Test R2=%.4f  RMSE=%.4f\n', r2_ridge_tr, r2_ridge_te, rmse_ridge_te);

%% -- 7. Lasso Regression (L1 penalty, coordinate descent) --
% Soft-threshold coordinate descent: eliminates irrelevant features
fprintf('\n[3] Lasso Regression (alpha=0.1)...\n');
alpha_lasso = 0.1;
max_iter_lasso = 5000;
tol = 1e-6;
theta_lasso = zeros(n, 1);
cost_lasso  = zeros(max_iter_lasso, 1);

for it = 1:max_iter_lasso
    theta_prev = theta_lasso;
    for j = 1:n
        % Partial residual excluding feature j
        r_j = y_train - X_train_b * theta_lasso + X_train_b(:,j) * theta_lasso(j);
        rho_j = X_train_b(:,j)' * r_j / m_train;
        z_j   = sum(X_train_b(:,j).^2) / m_train;

        if j == 1
            % Do not penalize bias
            theta_lasso(j) = rho_j / z_j;
        else
            % Soft-threshold operator
            theta_lasso(j) = soft_threshold(rho_j, alpha_lasso) / z_j;
        end
    end
    % Cost with L1 penalty
    err = X_train_b * theta_lasso - y_train;
    cost_lasso(it) = sum(err.^2)/(2*m_train) + alpha_lasso * sum(abs(theta_lasso(2:end)));

    % Convergence check
    if norm(theta_lasso - theta_prev) < tol
        fprintf('   Converged at iteration %d\n', it);
        cost_lasso = cost_lasso(1:it);
        break;
    end
end

zero_coef = sum(abs(theta_lasso(2:end)) < 1e-6);
fprintf('   Features eliminated by Lasso: %d / %d\n', zero_coef, n-1);

[r2_lasso_tr, rmse_lasso_tr] = eval_model(X_train_b, y_train, theta_lasso);
[r2_lasso_te, rmse_lasso_te] = eval_model(X_test_b,  y_test,  theta_lasso);
fprintf('   Train R2=%.4f  Test R2=%.4f  RMSE=%.4f\n', r2_lasso_tr, r2_lasso_te, rmse_lasso_te);

%% -- 8. Results Summary --
fprintf('\n==============================================\n');
fprintf('  Model         Train R2   Test R2   RMSE\n');
fprintf('----------------------------------------------\n');
fprintf('  Baseline GD   %.4f     %.4f    %.4f\n', r2_gd_tr,    r2_gd_te,    rmse_gd_te);
fprintf('  Ridge         %.4f     %.4f    %.4f\n', r2_ridge_tr,  r2_ridge_te,  rmse_ridge_te);
fprintf('  Lasso         %.4f     %.4f    %.4f\n', r2_lasso_tr,  r2_lasso_te,  rmse_lasso_te);
fprintf('==============================================\n');

%% -- 9. Visualization --
figure('Color','white','Position',[80 80 1400 800]);

% --- Row 1 ---
% Plot 1: GD loss curve
subplot(2,3,1);
plot(1:iter_gd, cost_gd, 'b-', 'LineWidth',1.8);
xlabel('Iteration'); ylabel('Cost J');
title('Baseline GD - Loss Curve');
grid on;

% Plot 2: Ridge predicted vs actual
subplot(2,3,2);
y_hat_ridge = X_test_b * theta_ridge;
scatter(y_test, y_hat_ridge, 35, 'filled', ...
    'MarkerFaceColor',[0.85 0.33 0.10], 'MarkerFaceAlpha',0.7);
hold on;
lims = [0 55];
plot(lims, lims, 'k--', 'LineWidth',1.4);
xlabel('Actual MEDV'); ylabel('Predicted MEDV');
title(sprintf('Ridge - Predicted vs Actual (R2=%.3f)', r2_ridge_te));
xlim(lims); ylim(lims); grid on;

% Plot 3: Lasso predicted vs actual
subplot(2,3,3);
y_hat_lasso = X_test_b * theta_lasso;
scatter(y_test, y_hat_lasso, 35, 'filled', ...
    'MarkerFaceColor',[0.13 0.70 0.37], 'MarkerFaceAlpha',0.7);
hold on;
plot(lims, lims, 'k--', 'LineWidth',1.4);
xlabel('Actual MEDV'); ylabel('Predicted MEDV');
title(sprintf('Lasso - Predicted vs Actual (R2=%.3f)', r2_lasso_te));
xlim(lims); ylim(lims); grid on;

% --- Row 2 ---
% Plot 4: R2 comparison bar chart
subplot(2,3,4);
r2_vals = [r2_gd_te, r2_ridge_te, r2_lasso_te];
b = bar(r2_vals, 0.5, 'FaceColor','flat');
b.CData = [0.20 0.45 0.80; 0.85 0.33 0.10; 0.13 0.70 0.37];
set(gca,'XTickLabel',{'Baseline','Ridge','Lasso'});
ylabel('Test R2');
title('Model Comparison - Test R2');
ylim([0 1]); grid on;
for i = 1:3
    text(i, r2_vals(i)+0.01, sprintf('%.4f', r2_vals(i)), ...
        'HorizontalAlignment','center','FontWeight','bold');
end

% Plot 5: RMSE comparison
subplot(2,3,5);
rmse_vals = [rmse_gd_te, rmse_ridge_te, rmse_lasso_te];
b2 = bar(rmse_vals, 0.5, 'FaceColor','flat');
b2.CData = [0.20 0.45 0.80; 0.85 0.33 0.10; 0.13 0.70 0.37];
set(gca,'XTickLabel',{'Baseline','Ridge','Lasso'});
ylabel('RMSE ($1000)');
title('Model Comparison - RMSE');
grid on;
for i = 1:3
    text(i, rmse_vals(i)+0.05, sprintf('%.4f', rmse_vals(i)), ...
        'HorizontalAlignment','center','FontWeight','bold');
end

% Plot 6: Lasso coefficient sparsity
subplot(2,3,6);
coef_vals = theta_lasso(2:end);
active_idx = find(abs(coef_vals) >= 1e-6);
zero_idx   = find(abs(coef_vals) <  1e-6);
bar_colors = repmat([0.13 0.70 0.37], length(coef_vals), 1);
bar_colors(zero_idx, :) = repmat([0.85 0.85 0.85], length(zero_idx), 1);
bh = bar(1:length(coef_vals), coef_vals, 'FaceColor','flat');
bh.CData = bar_colors;
xlabel('Feature index');
ylabel('Coefficient');
title(sprintf('Lasso Coefficients  (%d active / %d total)', ...
    length(active_idx), length(coef_vals)));
grid on;

sgtitle('Boston Housing: Poly + Ridge + Lasso', 'FontSize',14,'FontWeight','bold');
fprintf('\nDone. Figures generated.\n');

%% ================================================================
%  Helper Functions
%% ================================================================

function X_poly = poly_features(X)
% Generate degree-2 polynomial features (no bias term)
% Input:  X [m x n]
% Output: X_poly [m x (n + n*(n+1)/2)]
    [m, n] = size(X);
    X_poly = X;  % linear terms
    for i = 1:n
        for j = i:n
            X_poly = [X_poly, X(:,i) .* X(:,j)];
        end
    end
end

function val = soft_threshold(rho, lambda)
% Soft-threshold operator for Lasso coordinate descent
    if rho > lambda
        val = rho - lambda;
    elseif rho < -lambda
        val = rho + lambda;
    else
        val = 0;
    end
end

function [r2, rmse] = eval_model(X, y, theta)
% Compute R2 and RMSE given design matrix X, labels y, params theta
    y_hat  = X * theta;
    ss_res = sum((y - y_hat).^2);
    ss_tot = sum((y - mean(y)).^2);
    r2     = 1 - ss_res / ss_tot;
    rmse   = sqrt(mean((y - y_hat).^2));
end
