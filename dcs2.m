T = 1;

Gs = tf(1, [1 1 0]);
Gz = c2d(Gs, T, 'zoh');

K = 4;
G1z = K * Gz;

num_Gc = [0.544, -0.879, 0.349];
den_Gc = [1.000, -0.879, -0.107];
Gcz = tf(num_Gc, den_Gc, T);

G_open = Gcz * G1z;

figure;
margin(G_open);
grid on;
title('Bode Plot of Compensated Digital Control System');

T_cl = feedback(G_open, 1);

figure;
step(T_cl);
grid on;
title('Closed-Loop Step Response');