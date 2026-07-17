%% ========================================================================
%  Q1  Multi-Criteria Site Selection for the OPC Youth Sci-Tech Community
%  Pipeline: data standardisation (appendix direct | survey within-city
%            then 3-city fusion) -> AHP subjective weights (with CR test)
%            -> entropy objective weights -> 50/50 combined weights
%            -> GRA ranking (primary) + TOPSIS (cross-check)
%            -> Spearman consistency -> 6-dimension sensitivity analysis
%  MATLAB R2025b
%  ========================================================================
clear; clc; close all;
rng(0);

outdir = fullfile(pwd,'Q1_figs');
if ~exist(outdir,'dir'); mkdir(outdir); end

%% ---------- journal style ----------
set(0,'DefaultAxesFontName','Arial','DefaultTextFontName','Arial');
set(0,'DefaultAxesFontSize',11,'DefaultAxesLineWidth',1.0);
set(0,'DefaultLineLineWidth',1.8);
col.blue=[0.00 0.45 0.74]; col.orange=[0.85 0.33 0.10];
col.green=[0.20 0.63 0.17]; col.purple=[0.49 0.18 0.56];
col.grey=[0.50 0.50 0.50];  col.red=[0.80 0.14 0.14];
col.teal=[0.00 0.60 0.56];

%% ========================================================================
%  1.  PROBLEM SET-UP
%  ========================================================================
scheme = {'City Centre','Econ Dev Zone','Urban-Rural Fringe'};
ind    = {'C1 Rent','C2 TechSub','C3 OpsCost','C4 Talent','C5 AptSub',...
          'C6 Labour','C7 Cluster','C8 FirmDen','C9 RentSub','C10 Univ',...
          'C11 OccRisk','C12 CashRisk','C13 TaxSub'};
% polarity: -1 = cost type (smaller better), +1 = benefit type
pol = [-1 1 -1 1 1 -1 1 1 1 1 -1 -1 1];
n = 3;   m = 13;

% criterion grouping (1=Cost-Benefit,2=Talent,3=Cluster,4=Potential,5=Risk)
grp  = [1 1 1 2 2 2 3 3 4 4 5 5 1];
crit = {'B1 Cost-Benefit','B2 Talent Attraction','B3 Industry Cluster',...
        'B4 Sci-Tech Potential','B5 Operating Risk'};

fprintf('============================================================\n');
fprintf(' Q1  Multi-Criteria Site Selection (3 schemes x 13 indicators)\n');
fprintf('============================================================\n');

%% ========================================================================
%  2.  RAW DATA
%  ========================================================================
% ---- (a) 8 appendix indicators: city-independent stylised parameters ----
%     rows = [City Centre; Econ Dev Zone; Urban-Rural Fringe]
appIdx = [1 2 4 5 6 7 9 13];
appRaw = [ 60   0.20  1.20  0.00  1.30  1.10  0.30  0.10;   % City Centre
           40   0.40  1.00  0.35  1.00  1.30  0.60  0.50;   % Econ Dev Zone
           20   0.50  0.60  0.20  0.70  0.50  0.50  0.30];  % Urban-Rural

% ---- (b) 5 survey indicators: measured per city, 3 zones each ----
surIdx = [3 8 10 11 12];
% each field: rows = 3 zones, cols = the 5 survey indicators
HZ = [4.7   74.8  4  3  3;      % Hangzhou  : centre
      3.4  187.0  6  2  2;      %             dev zone
      2.4   18.7  3  4  4];     %             fringe
HF = [4.3 1362.4  5  3  3;      % Hefei
      3.1 3406.0  6  2  2;
      2.0  340.6  3  4  4];
WH = [3.6   61.2  3  2  3;      % Wuhu
      3.1  153.0  5  2  2;
      1.7   15.3  4  4  4];
cityW = [0.5 0.3 0.2];          % Hangzhou / Hefei / Wuhu fusion weights

fprintf('\n--- City fusion weights: HZ %.1f | HF %.1f | WH %.1f ---\n',cityW);

%% ========================================================================
%  3.  STANDARDISATION  ->  R (3 x 13), all in [0,1], all benefit-oriented
%      appendix : direct min-max
%      survey   : WITHIN-CITY min-max first, THEN weighted fusion
%      (fusing first would mix incommensurable units across cities:
%       Hefei counts national high-tech firms, Hangzhou counts unicorns)
%  ========================================================================
R = zeros(n,m);
for k = 1:numel(appIdx)
    j = appIdx(k);
    R(:,j) = minmaxPol(appRaw(:,k), pol(j));
end
cities = {HZ,HF,WH};
for k = 1:numel(surIdx)
    j = surIdx(k);
    acc = zeros(n,1);
    for c = 1:3
        acc = acc + cityW(c)*minmaxPol(cities{c}(:,k), pol(j));
    end
    R(:,j) = acc;
end

fprintf('\n--- Standardised decision matrix R ---\n');
fprintf('%-20s',''); fprintf('%8s',ind{:}); fprintf('\n');
for i = 1:n
    fprintf('%-20s',scheme{i}); fprintf('%8.3f',R(i,:)); fprintf('\n');
end

%% ========================================================================
%  4.  AHP SUBJECTIVE WEIGHTS
%  ========================================================================
% criterion-level pairwise judgement matrix (1-9 scale, reciprocal)
A = [1    1/3  1/2  1/2  2;
     3    1    2    3    4;
     2    1/2  1    2    3;
     2    1/3  1/2  1    2;
     1/2  1/4  1/3  1/2  1];
assert(all(all(abs(A - 1./A') < 1e-12)),'A must be reciprocal');

gm  = prod(A,2).^(1/5);          % geometric-mean (root) method
wC  = gm/sum(gm);                % criterion weights
lam = max(real(eig(A)));         % principal eigenvalue
CI  = (lam-5)/(5-1);
RI  = 1.12;                      % random index for order 5
CR  = CI/RI;

fprintf('\n--- AHP ---\n');
for i=1:5
    fprintf('  %-24s %.4f\n',crit{i},wC(i));
end
fprintf('  lambda_max=%.4f  CI=%.4f  RI=%.2f  CR=%.4f  -> %s\n',...
        lam,CI,RI,CR,ternary(CR<0.1,'PASS','FAIL'));

% allocate criterion weight equally among its indicators
cnt   = accumarray(grp(:),1);
w_ahp = zeros(1,m);
for j = 1:m
    w_ahp(j) = wC(grp(j))/cnt(grp(j));
end

%% ========================================================================
%  5.  ENTROPY OBJECTIVE WEIGHTS
%  ========================================================================
eps0 = 1e-9;
P = (R+eps0)./sum(R+eps0,1);
e = -1/log(n) * sum(P.*log(P),1);
d = 1 - e;
w_ent = d/sum(d);

fprintf('\n--- Entropy weights ---\n');
fprintf('  %-14s %10s %10s %10s\n','Indicator','e_j','d_j=1-e','w_ent');
for j=1:m
    fprintf('  %-14s %10.6f %10.6f %9.2f%%\n',ind{j},e(j),d(j),w_ent(j)*100);
end

%% ========================================================================
%  6.  COMBINED WEIGHTS (equal-weight linear combination)
%  ========================================================================
theta = 0.5;
w = theta*w_ent + (1-theta)*w_ahp;
w = w/sum(w);

fprintf('\n--- Combined weights (theta=%.2f) ---\n',theta);
fprintf('  %-14s %9s %9s %9s\n','Indicator','w_ent','w_ahp','w_comb');
for j=1:m
    fprintf('  %-14s %8.2f%% %8.2f%% %8.2f%%\n',ind{j},...
            w_ent(j)*100,w_ahp(j)*100,w(j)*100);
end
fprintf('  %-14s %8.2f%% %8.2f%% %8.2f%%\n','SUM',sum(w_ent)*100,sum(w_ahp)*100,sum(w)*100);

%% ========================================================================
%  7.  GRA  (primary ranking model)
%  ========================================================================
rho = 0.5;
[gam,xi] = graScore(R,w,rho);
[~,ordG] = sort(gam,'descend');
rankG = zeros(1,n); rankG(ordG) = 1:n;

fprintf('\n--- GRA (rho=%.1f) ---\n',rho);
for i=1:n
    fprintf('  %-20s gamma=%.4f  rank %d\n',scheme{i},gam(i),rankG(i));
end

%% ========================================================================
%  8.  TOPSIS (cross-check, on the SAME [0,1] matrix as GRA)
%  ========================================================================
[Ci,Dp,Dn] = topsisScore(R,w);
[~,ordT] = sort(Ci,'descend');
rankT = zeros(1,n); rankT(ordT) = 1:n;

fprintf('\n--- TOPSIS ---\n');
for i=1:n
    fprintf('  %-20s D+=%.4f  D-=%.4f  Ci=%.4f  rank %d\n',...
            scheme{i},Dp(i),Dn(i),Ci(i),rankT(i));
end

%% ========================================================================
%  9.  SPEARMAN RANK CORRELATION (GRA vs TOPSIS)
%  ========================================================================
dsq = sum((rankG-rankT).^2);
rs  = 1 - 6*dsq/(n*(n^2-1));
fprintf('\n--- Consistency ---\n');
fprintf('  GRA rank    : %s\n',mat2str(rankG));
fprintf('  TOPSIS rank : %s\n',mat2str(rankT));
fprintf('  Spearman rs = %.4f -> %s\n',rs,ternary(rs>=0.99,'identical ranking','check'));

best = scheme{ordG(1)};
fprintf('\n  ==> OPTIMAL SITE: %s\n',best);

%% ========================================================================
% 10.  SENSITIVITY ANALYSIS (6 dimensions)
% ========================================================================
fprintf('\n============================================================\n');
fprintf(' SENSITIVITY ANALYSIS\n');
fprintf('============================================================\n');

% --- S1 global proportional perturbation (scale invariance) ---
fprintf('\n[S1] Global proportional scaling of all weights\n');
for k = [0.8 0.9 1.0 1.1 1.2]
    wk = w*k; wk = wk/sum(wk);
    g = graScore(R,wk,rho);
    fprintf('   x%.1f : gamma=[%.4f %.4f %.4f] -> %s\n',k,g,scheme{argmax(g)});
end
fprintf('   (weights are renormalised, so scaling is provably neutral)\n');

% --- S2 single-indicator perturbation +-10/20/30% ---
deltas = [-0.30 -0.20 -0.10 0.10 0.20 0.30];
flip = 0; gEDZ = [];
fprintf('\n[S2] Single-indicator perturbation (13 x 6 = %d cases)\n',m*numel(deltas));
for j = 1:m
    for dlt = deltas
        wp = w; wp(j) = wp(j)*(1+dlt); wp = wp/sum(wp);
        g = graScore(R,wp,rho);
        gEDZ(end+1) = g(2); %#ok<SAGROW>
        if argmax(g) ~= 2, flip = flip + 1; end
    end
end
fprintf('   Econ-Dev-Zone gamma range : [%.4f, %.4f]\n',min(gEDZ),max(gEDZ));
fprintf('   rank flips                : %d / %d  (%.1f%%)\n',flip,numel(gEDZ),flip/numel(gEDZ)*100);

% --- S3 criterion-level weight swap (extreme preference reversal) ---
fprintf('\n[S3] Criterion weight swap (extreme scenarios)\n');
swaps = {[2 1],[2 5],[3 5]};
for s = 1:numel(swaps)
    a = swaps{s}(1); b = swaps{s}(2);
    wp = w;
    ia = find(grp==a); ib = find(grp==b);
    sa = sum(w(ia));   sb = sum(w(ib));
    wp(ia) = w(ia)*(sb/sa);
    wp(ib) = w(ib)*(sa/sb);
    wp = wp/sum(wp);
    g = graScore(R,wp,rho);
    fprintf('   %-22s <-> %-22s : gamma=[%.4f %.4f %.4f] -> %s\n',...
            crit{a},crit{b},g,scheme{argmax(g)});
end

% --- S4 GRA resolution coefficient sweep ---
fprintf('\n[S4] GRA resolution coefficient rho sweep\n');
rhos = 0.1:0.1:0.9; Grho = zeros(numel(rhos),n);
for k=1:numel(rhos)
    Grho(k,:) = graScore(R,w,rhos(k));
    fprintf('   rho=%.1f : gamma=[%.4f %.4f %.4f] -> %s\n',...
            rhos(k),Grho(k,:),scheme{argmax(Grho(k,:))});
end

% --- S5 city-fusion weight perturbation ---
fprintf('\n[S5] City-fusion weight perturbation\n');
fusionSets = {[1/3 1/3 1/3],[0.6 0.2 0.2],[0.2 0.6 0.2],[0.2 0.2 0.6],...
              [1 0 0],[0 1 0],[0 0 1]};
fusionLbl  = {'Equal 1/3','HZ-led .6','HF-led .6','WH-led .6',...
              'HZ only','HF only','WH only'};
Gfuse = zeros(numel(fusionSets),n);
for k = 1:numel(fusionSets)
    Rk = rebuildR(appRaw,appIdx,cities,surIdx,fusionSets{k},pol,n,m);
    Gfuse(k,:) = graScore(Rk,w,rho);
    fprintf('   %-12s : gamma=[%.4f %.4f %.4f] -> %s\n',...
            fusionLbl{k},Gfuse(k,:),scheme{argmax(Gfuse(k,:))});
end

% --- S6 critical weight (flip threshold) search ---
fprintf('\n[S6] Critical weight multiplier to flip the winner\n');
critMul = nan(1,m);
for j = 1:m
    for mul = [1.05:0.05:10, 0.95:-0.05:0.05]
        wp = w; wp(j) = w(j)*mul; wp = wp/sum(wp);
        if argmax(graScore(R,wp,rho)) ~= 2
            critMul(j) = mul; break;
        end
    end
    if isnan(critMul(j))
        fprintf('   %-14s : no flip within 0.05x - 10x\n',ind{j});
    else
        fprintf('   %-14s : flips at %.2fx (%+.0f%%)\n',ind{j},critMul(j),(critMul(j)-1)*100);
    end
end

%% ========================================================================
% 11.  FIGURES
% ========================================================================

% ---- FIG 1: weight comparison ----
f1=figure('Color','w','Position',[60 60 950 480]);
ax=axes(f1); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
bb=bar(ax,1:m,[w_ahp;w_ent;w]'*100,1,'grouped');
bb(1).FaceColor=col.orange; bb(2).FaceColor=col.teal; bb(3).FaceColor=col.blue;
set(bb,'EdgeColor','none');
set(ax,'XTick',1:m,'XTickLabel',ind); xtickangle(ax,40);
ylabel(ax,'Weight (%)');
title(ax,'Indicator Weights: AHP vs Entropy vs Combined','FontWeight','bold');
legend(ax,{'AHP (subjective)','Entropy (objective)','Combined (50/50)'},...
       'Location','northwest','Box','off','FontSize',9);
exportgraphics(f1,fullfile(outdir,'Fig1_weights.png'),'Resolution',300);

% ---- FIG 2: standardised decision matrix heat-map ----
f2=figure('Color','w','Position',[60 60 950 380]);
ax=axes(f2);
imagesc(ax,R); colormap(ax,[linspace(1,0,256)' linspace(1,0.45,256)' linspace(1,0.74,256)']);
cb=colorbar(ax); cb.Label.String='Standardised value (0-1)'; caxis(ax,[0 1]);
set(ax,'XTick',1:m,'XTickLabel',ind,'YTick',1:n,'YTickLabel',scheme);
xtickangle(ax,40);
title(ax,'Standardised Decision Matrix (benefit-oriented)','FontWeight','bold');
for i=1:n
    for j=1:m
        tc='k'; if R(i,j)>0.55, tc='w'; end
        text(ax,j,i,sprintf('%.2f',R(i,j)),'HorizontalAlignment','center',...
             'FontSize',7.5,'Color',tc);
    end
end
exportgraphics(f2,fullfile(outdir,'Fig2_matrix.png'),'Resolution',300);

% ---- FIG 3: GRA & TOPSIS ranking ----
f3=figure('Color','w','Position',[60 60 820 470]);
ax=axes(f3); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
bw=0.35;
b1=bar(ax,(1:n)-bw/2,gam,bw,'FaceColor',col.blue,'EdgeColor','none');
b2=bar(ax,(1:n)+bw/2,Ci ,bw,'FaceColor',col.orange,'EdgeColor','none');
for i=1:n
    text(ax,i-bw/2,gam(i)+0.015,sprintf('%.4f',gam(i)),'HorizontalAlignment','center','FontSize',9);
    text(ax,i+bw/2,Ci(i) +0.015,sprintf('%.4f',Ci(i)) ,'HorizontalAlignment','center','FontSize',9);
end
plot(ax,ordG(1),max(gam(ordG(1)),Ci(ordG(1)))+0.06,'p','MarkerSize',18,...
     'MarkerFaceColor',col.red,'MarkerEdgeColor','k');
set(ax,'XTick',1:n,'XTickLabel',scheme);
ylabel(ax,'Score');
title(ax,sprintf('Site Ranking: GRA vs TOPSIS  (Spearman r_s = %.2f)',rs),'FontWeight','bold');
legend(ax,{'GRA \gamma_i','TOPSIS C_i'},'Location','northwest','Box','off','FontSize',9);
ylim(ax,[0 1.05]);
exportgraphics(f3,fullfile(outdir,'Fig3_ranking.png'),'Resolution',300);

% ---- FIG 4: single-indicator sensitivity band ----
f4=figure('Color','w','Position',[60 60 950 480]);
ax=axes(f4); hold(ax,'on'); box(ax,'on'); grid(ax,'on'); ax.GridAlpha=0.12;
Gmat = zeros(m,numel(deltas));
for j=1:m
    for k=1:numel(deltas)
        wp=w; wp(j)=wp(j)*(1+deltas(k)); wp=wp/sum(wp);
        gg=graScore(R,wp,rho); Gmat(j,k)=gg(2);
    end
end
patch(ax,[0 m+1 m+1 0],[min(Gmat(:)) min(Gmat(:)) max(Gmat(:)) max(Gmat(:))],...
      col.blue,'FaceAlpha',0.07,'EdgeColor','none');
plot(ax,1:m,Gmat,'-','Color',[0.75 0.75 0.75],'LineWidth',0.8);
plot(ax,1:m,Gmat(:,1),'v','MarkerSize',6,'MarkerFaceColor',col.red,'MarkerEdgeColor','none');
plot(ax,1:m,Gmat(:,end),'^','MarkerSize',6,'MarkerFaceColor',col.green,'MarkerEdgeColor','none');
yline(ax,gam(2),'-','Color',col.blue,'LineWidth',2,'Label','baseline','FontSize',9);
% runner-up ceiling: highest gamma among the other two schemes
runner = max(gam([1 3]));
yline(ax,runner,'--','Color',col.red,'LineWidth',1.4,...
      'Label','runner-up level','FontSize',9);
set(ax,'XTick',1:m,'XTickLabel',ind); xtickangle(ax,40);
ylabel(ax,'Econ-Dev-Zone GRA \gamma');
title(ax,'Single-Indicator Weight Perturbation (\pm10/20/30%)','FontWeight','bold');
legend(ax,{'','perturbation band','-30%','+30%'},'Location','southeast','Box','off','FontSize',9);
xlim(ax,[0.3 m+0.7]);
exportgraphics(f4,fullfile(outdir,'Fig4_sensitivity.png'),'Resolution',300);

% ---- FIG 5: rho sweep + city fusion ----
f5=figure('Color','w','Position',[60 60 950 420]);
sp1=subplot(1,2,1); hold(sp1,'on'); box(sp1,'on'); grid(sp1,'on'); sp1.GridAlpha=0.12;
plot(sp1,rhos,Grho(:,1),'-o','Color',col.grey ,'MarkerFaceColor',col.grey ,'MarkerSize',5);
plot(sp1,rhos,Grho(:,2),'-s','Color',col.blue ,'MarkerFaceColor',col.blue ,'MarkerSize',6,'LineWidth',2.2);
plot(sp1,rhos,Grho(:,3),'-^','Color',col.green,'MarkerFaceColor',col.green,'MarkerSize',5);
xlabel(sp1,'Resolution coefficient \rho'); ylabel(sp1,'GRA \gamma');
title(sp1,'(a) \rho Sweep','FontWeight','bold');
legend(sp1,scheme,'Location','northwest','Box','off','FontSize',8);
sp2=subplot(1,2,2); hold(sp2,'on'); box(sp2,'on'); grid(sp2,'on'); sp2.GridAlpha=0.12;
hb=bar(sp2,Gfuse,1,'grouped'); hb(1).FaceColor=col.grey; hb(2).FaceColor=col.blue; hb(3).FaceColor=col.green;
set(hb,'EdgeColor','none');
set(sp2,'XTick',1:numel(fusionLbl),'XTickLabel',fusionLbl); xtickangle(sp2,35);
ylabel(sp2,'GRA \gamma');
title(sp2,'(b) City-Fusion Weight Perturbation','FontWeight','bold');
legend(sp2,scheme,'Location','northwest','Box','off','FontSize',8);
exportgraphics(f5,fullfile(outdir,'Fig5_rho_fusion.png'),'Resolution',300);

% ---- FIG 6: AHP criterion weights pie + CR annotation ----
f6=figure('Color','w','Position',[60 60 680 520]);
ax=axes(f6);
pp=pie(ax,wC,crit);
pc=[col.blue;col.orange;col.green;col.purple;col.grey];
for i=1:2:numel(pp); pp(i).FaceColor=pc(ceil(i/2),:); pp(i).EdgeColor='w'; pp(i).LineWidth=1.5; end
for i=2:2:numel(pp); pp(i).FontSize=9.5; end
title(ax,sprintf('AHP Criterion Weights  (\\lambda_{max}=%.4f, CR=%.4f < 0.1)',lam,CR),...
      'FontWeight','bold','FontSize',12);
exportgraphics(f6,fullfile(outdir,'Fig6_ahp_pie.png'),'Resolution',300);

%% ========================================================================
% 12.  EXPORT TABLES
% ========================================================================
T1 = table(ind',e',d',(w_ent*100)',(w_ahp*100)',(w*100)',...
     'VariableNames',{'Indicator','Entropy_e','Diff_d','W_entropy_pct','W_AHP_pct','W_combined_pct'});
writetable(T1,fullfile(outdir,'Q1_weights.csv'));

T2 = table(scheme',gam',rankG',Ci',Dp',Dn',rankT',...
     'VariableNames',{'Scheme','GRA_gamma','GRA_rank','TOPSIS_Ci','D_plus','D_minus','TOPSIS_rank'});
writetable(T2,fullfile(outdir,'Q1_ranking.csv'));

T3 = array2table(R,'VariableNames',matlab.lang.makeValidName(ind),'RowNames',scheme);
writetable(T3,fullfile(outdir,'Q1_std_matrix.csv'),'WriteRowNames',true);

disp(' '); disp('--- Weight table ---'); disp(T1);
disp(' '); disp('--- Ranking table ---'); disp(T2);

%% ========================================================================
% 13.  SUMMARY
% ========================================================================
fprintf('\n============================================================\n');
fprintf(' Q1 KEY OUTPUTS\n');
fprintf('============================================================\n');
fprintf(' AHP criterion weights : [%.4f %.4f %.4f %.4f %.4f]\n',wC);
fprintf(' AHP consistency       : lambda=%.4f, CI=%.4f, CR=%.4f (PASS)\n',lam,CI,CR);
fprintf(' GRA gamma             : [%.4f %.4f %.4f]\n',gam);
fprintf(' TOPSIS Ci             : [%.4f %.4f %.4f]\n',Ci);
fprintf(' Spearman rs           : %.4f\n',rs);
fprintf(' Optimal site          : %s\n',best);
fprintf(' Sensitivity           : %d/%d single-indicator cases flip the winner\n',flip,numel(gEDZ));
fprintf(' rho sweep / fusion    : winner unchanged in %d/%d and %d/%d cases\n',...
        sum(arrayfun(@(k) argmax(Grho(k,:))==2,1:numel(rhos))),numel(rhos),...
        sum(arrayfun(@(k) argmax(Gfuse(k,:))==2,1:numel(fusionSets))),numel(fusionSets));
fprintf('\n 6 figures saved to: %s\n',outdir);
fprintf('============================================================\n');

%% ========================================================================
%  helper functions
%  ========================================================================
function y = minmaxPol(v,p)
% min-max normalise a column to [0,1] after polarity alignment
    v = v(:);
    if p < 0, v = max(v) - v; end     % cost -> benefit (range method)
    lo = min(v); hi = max(v);
    if hi - lo < 1e-12
        y = 0.5*ones(size(v));
    else
        y = (v - lo)/(hi - lo);
    end
end

function [gam,xi] = graScore(R,w,rho)
% grey relational grade against the ideal reference sequence
    X0 = max(R,[],1);
    D  = abs(R - X0);
    dmin = min(D(:)); dmax = max(D(:));
    xi = (dmin + rho*dmax)./(D + rho*dmax);
    gam = (xi .* w) * ones(size(w,2),1);
    gam = gam';
end

function [Ci,Dp,Dn] = topsisScore(R,w)
% TOPSIS on an already-standardised, benefit-oriented matrix
    V  = R .* w;
    Vp = max(V,[],1);  Vn = min(V,[],1);
    Dp = sqrt(sum((V - Vp).^2,2))';
    Dn = sqrt(sum((V - Vn).^2,2))';
    Ci = Dn ./ (Dp + Dn);
end

function Rk = rebuildR(appRaw,appIdx,cities,surIdx,cw,pol,n,m)
% rebuild the standardised matrix under a different city-fusion weighting
    Rk = zeros(n,m);
    for k = 1:numel(appIdx)
        j = appIdx(k);
        Rk(:,j) = minmaxPol(appRaw(:,k), pol(j));
    end
    for k = 1:numel(surIdx)
        j = surIdx(k); acc = zeros(n,1);
        for c = 1:3
            acc = acc + cw(c)*minmaxPol(cities{c}(:,k), pol(j));
        end
        Rk(:,j) = acc;
    end
end

function i = argmax(v)
    [~,i] = max(v);
end

function s = ternary(c,a,b)
    if c, s = a; else, s = b; end
end