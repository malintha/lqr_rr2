clear;
addpath('./mr/')

% L1, L2: arm lengths
L1 = 0.5;
L2 = 0.5;
theta_min = 0.1;

robot = get2RRobot(L1, L2);

% start and goal positions for the end effector
qinit = [theta_min ; theta_min];

start = [L1*cos(theta_min) + L2*cos(2*theta_min) ...
        L1*sin(theta_min) + L2*sin(2*theta_min)];
target = [-0.5 0.6];

% times for cartesian trajectory generation
dt = 0.1;
Tf = 3;

% calculate the cartesian trajectory
st_tr = trvec2tform([start 0]);
target_tr = trvec2tform([target 0]);
traj = CartesianTrajectory(st_tr, target_tr, Tf, Tf/dt, 5);

% system matrices for LQR with some modelling noise
A = @(theta1,theta2) [1 0 (-L1*sin(theta1)-L2*sin(theta1+theta2)) (-L2*sin(theta1+theta2)); ... 
                     0 1 (L1*cos(theta1)+L2*cos(theta1+theta2)) (L2*cos(theta1+theta2)); ...
                     0 0 1 0; ... 
                     0 0 0 1];
                
B = @(theta1,theta2) [-L1*sin(theta1)-L2*sin(theta1+theta2) -L2*sin(theta1+theta2); ...
                    L1*cos(theta1)+L2*cos(theta1+theta2) L2*cos(theta1+theta2);
                    1 0; 
                    0 1];
                
% cost matrices Q: state, R: control
Q = [10 0 0 0; 
     0 10 0 0;
     0 0 10 0
     0 0 0 10];
 
% use 0.1 to increase the aggressiveness of control  
R = [1 0;
    0 1];

% initial conditions for the system
% q = qinit;
x0 = [start'; qinit(1); qinit(2)];

% matrices for plotting
xs = [];
es = [];
xbars = [];

% initialize inverse kinematics
weights = [0, 0, 0, 1, 1, 0];
ik = inverseKinematics('RigidBodyTree', robot);

ddt = 0.01;
for i=2:length(traj)
    if i<length(traj)
        [~, x_bar] = TransToRp(traj{i});
    else
        [~, x_bar] = TransToRp(traj{end});
    end

%     get the theta_bar that needs the robot to be stabilized around
    q_bar = ik('tool', trvec2tform([x0(1:2)' 0]), weights, x0(3:4));
    x_bar = [x_bar(1:2); q_bar];
    
%     linearized system around the fixed point 
    At = A(q_bar(1), q_bar(2));
    Bt = B(q_bar(1), q_bar(2));
    
%     get the LQR gain matrix
    k = lqr(At, Bt, Q, R);
    
% solve the system with kinematics
% use state as [x y theta1 theta2]
    tspan = (0:ddt:dt);
    [~, xt] = ode45(@(t,xt)non_sys_4x1(xt, x_bar, k), tspan, x0);
    x0 = xt(end,:)';
    
    % plotting data
    es = [es; xt(:,1:2)-x_bar(1:2)'];
    xs = [xs; xt];
    xbars = [xbars; x_bar'];
end

%% animate the robot
% Note: Animating is slower than the actual rate when the time resolution 
% is too high, especially when the results from the ODE integration is passed.
qs = xs(:,3:4);
% figure('Renderer', 'painters', 'Position', [1500 100 600 600]);
h = figure;
f1 = show(robot,qs(1,:)');
view(2);
ax = gca;
ax.Projection = 'orthographic';

% xlim([-1.2 1.2]);
% ylim([-1.2 1.2]);
title('Angular & Cartesian Fixed Points Stabilization');
hold on

% plot the goal and trajectory
scatter(target(1),target(2),40,'*b');
scatter(start(1),start(2),40,'*g');
plot(xbars(:,1),xbars(:,2),'-g','LineWidth',1);
hold off

%%
t = ddt;
p1 = es(1,1);
p2 = es(1,2);
p3 = xs(1,1);
p4 = xs(1,2);
p5 = xs(1,3);
p6 = xs(1,4);

t_max = length(es)*ddt;
% t_ = (ddt:ddt:t_max);
te = (dt:dt:length(xbars)*dt);


error_fig = figure;

subplot(3,2,[1,2]);
p1_h = plot(t,p1,'-r','LineWidth',1);
hold on
p2_h = plot(t,p2,'-g');
xlabel('Time (s)');
ylabel('Absolute Error (m)');
legend('X Error','Y Error');
xlim([0 t_max]);
ylim([-1 1]);
hold off

subplot(3,2,[3,4]);
p3_h = plot(t,p3,'-r','LineWidth',1);
hold on
p4_h = plot(t,p4,'-g');
plot(te,xbars(:,1),'-+k',te,xbars(:,2),'-+b','LineWidth',0.5);
legend('X','Y','X Set','Y Set');
xlabel('Time (s)');
ylabel('Displacement(m)');
xlim([0 t_max]);
% ylim([-1 1]);
hold off

subplot(3,2,[5,6]);
p5_h = plot(t,p5,'-r','LineWidth',1);
hold on
p6_h = plot(t, p6,'-g');
if(size(xbars,2)>2)
plot(te,xbars(:,3),'-+k',te,xbars(:,4),'-+b','LineWidth',0.5);
    legend('Joint_1 Angle','Joint_2 Angle','Joint_1 Set','Joint_2 Set');
else
    legend('Joint_1 Angle','Joint_2 Angle');
end
xlabel('Time (s)');
ylabel('Angle(rad)');
xlim([0 t_max]);
hold off


p1_h.YDataSource = 'p1';
p1_h.XDataSource = 't';
p2_h.YDataSource = 'p2';
p2_h.XDataSource = 't';
p3_h.YDataSource = 'p3';
p3_h.XDataSource = 't';
p4_h.YDataSource = 'p4';
p4_h.XDataSource = 't';
p5_h.YDataSource = 'p5';
p5_h.XDataSource = 't';
p6_h.YDataSource = 'p6';
p6_h.YDataSource = 't';

% linkdata on
%%
framesPerSecond = length(xs)/Tf;
r = rateControl(framesPerSecond);

for i = 1:length(qs)
    figure(h)
    f1 = show(robot,qs(i,:)','PreservePlot',false);
    view(2);
    ax = gca;
    ax.Projection = 'orthographic';

    title('Angular & Cartesian Fixed Points Stabilization');
    hold on
    
    h1=findall(f1); %finding all objects in figure
    hlines=h1.findobj('Type','Line'); %finding line object 
    %editing line object properties
    n=size(hlines);
    for j=1:2
        hlines(j).LineWidth = 3; %chanding line width
        hlines(j).Color=[1 0 0.5];%changing line color
        hlines(j).Marker='o';%changing marker type
        hlines(j).MarkerSize=5; %changing marker size
    end
    

    
    t = [t (i+1)*ddt];
    p1 = [p1 es(i,1)];
    p2 = [p2 es(i,2)];
    p3 = [p3 xs(i,1)];
    p4 = [p4 xs(i,2)];
    p5 = [p5 xs(i,1)];
    p6 = [p6 xs(i,2)];
    refreshdata(error_fig)
    
    %% save to gif
%     filename = './plots/added_noise1.gif';
%     frame = getframe(1);
%     im = frame2im(frame);
%     [imind,cm] = rgb2ind(im,256);
%     if i == 1 
%       imwrite(imind,cm,filename,'gif', 'Loopcount',inf);
%     else
%       imwrite(imind,cm,filename,'gif','Writemode','append', 'DelayTime', dt);
%     end

drawnow
    waitfor(r);

end
hold off
% visualize the plots
visualize_plots(ddt, dt, es, xs, xbars);